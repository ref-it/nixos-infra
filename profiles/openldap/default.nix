{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.openldap;

  suffix = "dc=stura-ilmenau,dc=de";
  realmDn = realm: "ou=${realm},ou=Communities,${suffix}";
  servicesDn = realm: "ou=Services,${realmDn realm}";
  serviceDn = realm: name: "cn=${name},${servicesDn realm}";
  servicePolicyDn = "cn=services,ou=policies,${suffix}";

  # Root on this host via ldapi:/// (SASL EXTERNAL), used to manage the
  # service accounts. Not reachable over the network.
  rootPeercred = "gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth";

  communitiesDn = "ou=Communities,${suffix}";
  globalServicesDn = "ou=Services,${suffix}";

  # Any service account, of a realm or global. ACL regexes match the
  # normalized (lowercase) DN.
  anyServiceRegex = "^cn=[^,]+,ou=services,(ou=[^,]+,ou=communities,)?${suffix}$";

  credentialsDir = "/var/lib/openldap-service-credentials";

  # Where service accounts live: each realm's ou=Services, plus the global one
  # for services working on all realms. `dir` is the credentials subdirectory.
  scopes =
    mapAttrsToList (realm: realmCfg: { dir = realm; dn = servicesDn realm; services = realmCfg.services; }) cfg.realms
    ++ [ { dir = "global"; dn = globalServicesDn; services = cfg.globalServices; } ];

  dnsWhere = pred: scopeDn: services:
    map (name: "cn=${name},${scopeDn}") (attrNames (filterAttrs (_: pred) services));
  dnsWith = access: dnsWhere (svc: svc.access == access);
  realmServices = access: realm: dnsWith access (servicesDn realm) cfg.realms.${realm}.services;
  globalServices = access: dnsWith access globalServicesDn cfg.globalServices;

  by = level: concatMapStrings (dn: "\n      by dn.exact=\"${dn}\" ${level}");

  # Service entries (global and of every realm): bind only, invisible and
  # unmodifiable for everyone (themselves included, passwords are managed by
  # openldap-service-accounts). First rule after root, so no other rule (e.g.
  # a write service's access) applies to them.
  serviceEntryAcl = ''to dn.regex="^(.+,)?ou=services,(ou=[^,]+,ou=communities,)?${suffix}$"
      by anonymous auth
      by * none'';

  # Password attributes of people: write services may set passwords (=w:
  # without reading the hashes) and unlock accounts. Placed before the
  # generic password rules, which apply to everyone else.
  passwordAcls = scopeDn: servicesBase: services:
    let
      writers = dnsWith "write" servicesBase services;
      hashes = svc: svc.readPasswordHashes;
      writeHashes = dnsWhere (svc: svc.access == "write" && hashes svc) servicesBase services;
      writeOnly = dnsWhere (svc: svc.access == "write" && !hashes svc) servicesBase services;
      readHashes = dnsWhere (svc: svc.access == "read" && hashes svc) servicesBase services;
    in
      optional (writers ++ readHashes != [])
        ''to dn.subtree="${scopeDn}" attrs=userPassword${by "write" writeHashes}${by "=w" writeOnly}${by "read" readHashes}
      by * break''
      ++ optional (writers != [])
        # All password policy state, incl. pwdLastSuccess (StuMV detects inactive
        # accounts by it). Operational ones like pwdLastSuccess stay read-only.
        ''to dn.subtree="${scopeDn}" attrs=pwdFailureTime,pwdAccountLockedTime,pwdChangedTime,pwdReset,pwdHistory,pwdLastSuccess${by "write" writers}
      by * break'';
  writerPasswordAcls = passwordAcls communitiesDn globalServicesDn cfg.globalServices
    ++ concatMap (realm: passwordAcls (realmDn realm) (servicesDn realm) cfg.realms.${realm}.services) (attrNames cfg.realms);

  # Global services: their access to all realms, before the per-realm rules.
  globalAcls = optional (globalServices "write" ++ globalServices "read" != [])
    ''to dn.subtree="${communitiesDn}"${by "write" (globalServices "write")}${by "read" (globalServices "read")}
      by * break'';

  # A realm's own services read (or write) it, other services get nothing.
  realmAcls = map (realm:
    ''to dn.subtree="${realmDn realm}"${by "write" (realmServices "write" realm)}${by "read" (realmServices "read" realm)}
      by dn.regex="${anyServiceRegex}" none
      by users read''
  ) (attrNames cfg.realms);

  # olcAccess needs "{n}" prefixes to keep the order.
  numbered = imap0 (i: acl: "{${toString i}}${acl}");

  syncServiceAccounts = pkgs.writeShellScript "openldap-service-accounts" ''
    set -euo pipefail
    export PATH=${makeBinPath [ pkgs.openldap pkgs.openssl pkgs.coreutils pkgs.gnugrep pkgs.gnused ]}
    LDAP=(-Q -Y EXTERNAL -H ldapi:///)

    exists() { ldapsearch "''${LDAP[@]}" -LLL -s base -b "$1" dn >/dev/null 2>&1; }

    if ! exists "${servicePolicyDn}"; then
      echo "creating ${servicePolicyDn}"
      ldapadd "''${LDAP[@]}" <<EOF
    dn: ${servicePolicyDn}
    objectClass: top
    objectClass: device
    objectClass: pwdPolicy
    cn: services
    pwdAttribute: userPassword
    pwdLockout: FALSE
    EOF
    fi

    install -d -m 0700 ${credentialsDir}

    ${concatMapStrings (scope: let names = attrNames scope.services; in ''
      install -d -m 0700 ${credentialsDir}/${scope.dir}
      ${optionalString (names != []) ''
        if ! exists "${scope.dn}"; then
          echo "creating ${scope.dn}"
          ldapadd "''${LDAP[@]}" <<EOF
    dn: ${scope.dn}
    objectClass: organizationalUnit
    ou: Services
    EOF
        fi
      ''}

      ${concatMapStrings (name: let dn = "cn=${name},${scope.dn}"; pwFile = "${credentialsDir}/${scope.dir}/${name}"; in ''
        if [ ! -s ${pwFile} ]; then
          # No trailing newline: `ldapwhoami -y` would treat it as part of the password.
          (umask 077; openssl rand -hex 24 | tr -d '\n' > ${pwFile})
        fi
        if ! exists "${dn}"; then
          echo "creating ${dn}"
          # Cleartext is hashed by ppolicy (olcPPolicyHashCleartext).
          ldapadd "''${LDAP[@]}" <<EOF
    dn: ${dn}
    objectClass: applicationProcess
    objectClass: simpleSecurityObject
    cn: ${name}
    userPassword: $(cat ${pwFile})
    pwdPolicySubentry: ${servicePolicyDn}
    EOF
        elif ! ldapwhoami -x -H ldapi:/// -D "${dn}" -y ${pwFile} >/dev/null 2>&1; then
          echo "resetting password of ${dn}"
          ldapmodify "''${LDAP[@]}" <<EOF
    dn: ${dn}
    changetype: modify
    replace: userPassword
    userPassword: $(cat ${pwFile})
    EOF
        fi
      '') names}

      if exists "${scope.dn}"; then
        ldapsearch "''${LDAP[@]}" -LLL -o ldif-wrap=no -s one -b "${scope.dn}" "(objectClass=applicationProcess)" cn \
          | sed -n 's/^cn: //p' | while read -r name; do
            case " ${concatStringsSep " " names} " in
              *" $name "*) ;;
              *)
                echo "removing cn=$name,${scope.dn}"
                ldapdelete "''${LDAP[@]}" "cn=$name,${scope.dn}"
                rm -f "${credentialsDir}/${scope.dir}/$name"
                ;;
            esac
          done
      fi
    '') scopes}
  '';
in
{
  options.profiles.openldap = {
    enable = mkEnableOption (mdDoc "Enable the OpenLDAP profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN of the OpenLDAP.
      '';
    };

    realms = mkOption {
      type = types.attrsOf (types.submodule {
        options.services = mkOption {
          type = types.attrsOf (types.submodule {
            options.access = mkOption {
              type = types.enum [ "read" "write" ];
              default = "read";
              description = mdDoc ''
                `read`: read the realm's entries (no password hashes).
                `write`: additionally create, modify and delete entries,
                set passwords (without reading hashes) and unlock accounts,
                e.g. for member management.
              '';
            };
            options.readPasswordHashes = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc ''
                Allow reading `userPassword` (the hashes). Only for services that
                need them, e.g. StuMV mirrors them into its own database.
              '';
            };
          });
          default = {};
          description = mdDoc ''
            Service accounts of this realm, created as
            `cn=<name>,ou=Services,ou=<realm>,ou=Communities,${suffix}`.
            They can bind and access the realm's entries, nothing else.
            Passwords are generated on first deploy and stored in
            `${credentialsDir}/<realm>/<name>`. Removing a name deletes the
            account.
          '';
        };
      });
      default = {};
      example = literalExpression ''{ stura.services = { zammad = {}; members.access = "write"; }; }'';
      description = mdDoc "Realms (`ou=<realm>,ou=Communities`) with service accounts.";
    };

    globalServices = mkOption {
      type = types.attrsOf (types.submodule {
        options.access = mkOption {
          type = types.enum [ "read" "write" ];
          default = "read";
          description = mdDoc "Like a realm service's `access`, but for all realms.";
        };
        options.readPasswordHashes = mkOption {
          type = types.bool;
          default = false;
          description = mdDoc ''
            Allow reading `userPassword` (the hashes). Only for services that
            need them, e.g. StuMV mirrors them into its own database.
          '';
        };
      });
      default = {};
      example = literalExpression ''{ stumv.access = "write"; }'';
      description = mdDoc ''
        Service accounts working on all realms below `ou=Communities` (also
        future ones), created as `cn=<name>,ou=Services,${suffix}`. Passwords
        are stored in `${credentialsDir}/global/<name>`.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = concatMap (scope: map (name: {
      assertion = builtins.match "[a-z0-9-]+" name != null;
      message = "profiles.openldap service account ${name} (${scope.dn}): use lowercase letters, digits and dashes only.";
    }) (attrNames scope.services)) scopes ++ [{
      assertion = !(cfg.realms ? global);
      message = "profiles.openldap.realms.global: the name is reserved for the credentials of global services.";
    }];

    networking.firewall = {
      allowedTCPPorts = [ 80 ];
      extraInputRules = ''
        ip saddr 10.170.20.103 tcp dport { 389, 636 } accept comment "obelix"
        ip saddr 10.170.20.104 tcp dport { 389, 636 } accept comment "miraculix"
        ip6 saddr 2001:638:904:ffbe::190 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::191 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::192 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::193 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbf::54 tcp dport { 389, 636 } accept comment "web-2-manage"
      '';
    };

    sops.secrets = {
      "openldap-pw" = {
        owner = "openldap";
        group = "openldap";
        mode = "0400";
        restartUnits = [ "openldap.service" ];
      };
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    services.openldap = {
      enable = true;

      /* enable plain and secure connections */
      urlList = [ "ldap:///" "ldaps:///" "ldapi:///" ];

      settings = {
        attrs = {
          olcLogLevel = "stats";

          /* settings for acme ssl */
          olcTLSCACertificateFile = "/var/lib/acme/${cfg.fqdn}/full.pem";
          olcTLSCertificateFile = "/var/lib/acme/${cfg.fqdn}/cert.pem";
          olcTLSCertificateKeyFile = "/var/lib/acme/${cfg.fqdn}/key.pem";
          olcTLSCipherSuite = "HIGH:!aNULL:!eNULL:!3DES:!RC4:!MD5:!EXPORT";
          olcTLSCRLCheck = "none";
          olcTLSVerifyClient = "never";
          olcTLSProtocolMin = "3.3";
        };

        children = {
          "cn=schema".includes = [
            "${pkgs.openldap}/etc/schema/core.ldif"
            "${pkgs.openldap}/etc/schema/cosine.ldif"
            "${pkgs.openldap}/etc/schema/nis.ldif"
            "${pkgs.openldap}/etc/schema/namedobject.ldif"
            "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
            "${pkgs.openldap}/etc/schema/dyngroup.ldif"
          ];

          "cn=module{0}" = {
            attrs = {
              objectClass = [ "olcModuleList" ];
              olcModuleLoad = [
                "ppolicy"
                "argon2"
                "dynlist"
                "sssvlv"
              ];
            };
          };

          "olcDatabase={1}mdb" = {
            attrs = {
              objectClass = [
                "olcDatabaseConfig"
                "olcMdbConfig"
              ];

              olcDatabase = "{1}mdb";
              olcDbDirectory = "/var/lib/openldap/data";
              olcDbMaxsize = "4294967296";

              olcSuffix = "dc=stura-ilmenau,dc=de";

              olcRootDN = "cn=admin,dc=stura-ilmenau,dc=de";
              olcRootPW.path = config.sops.secrets."openldap-pw".path;

              olcLastBind = "TRUE";
              olcLastBindPrecision = "60";

              # New indexes only cover existing entries after slapindex, which
              # runs before every start (see systemd.services.openldap).
              olcDbIndex = [
                "objectClass eq"
                "entryUUID eq"
                "uid eq,sub"
                "cn eq,sub"
                "mail eq"
                "ou eq"
                "member eq"
                "uniqueMember eq"
              ];

              # The default size limit (500) applies to every bind except the
              # rootDN, and the realms have more people than that.
              olcLimits = numbered [
                ''dn.exact="${rootPeercred}" size=unlimited time=unlimited''
                ''dn.regex="${anyServiceRegex}" size=unlimited time=unlimited''
              ];

              olcAccess = numbered ([
                ''to *
                  by dn.exact="${rootPeercred}" manage
                  by * break''
                serviceEntryAcl
              ] ++ writerPasswordAcls ++ [

                ''to attrs=userPassword
                  by self write
                  by anonymous auth
                  by * none''

                ''to attrs=pwdFailureTime,pwdAccountLockedTime,pwdChangedTime,pwdReset,pwdHistory,pwdLastSuccess
                  by self read
                  by * none''
              ] ++ globalAcls ++ realmAcls ++ [
                # Only the root entry itself, so services can search from the
                # suffix (e.g. StuMV looks up entries by entryUUID from there).
                ''to dn.base="${suffix}"
                  by dn.regex="${anyServiceRegex}" read
                  by * break''

                ''to *
                  by dn.regex="${anyServiceRegex}" none
                  by users read''
              ]);
            };
          
            children = {
              "olcOverlay={0}dynlist".attrs = {
                objectClass = [
                  "olcDynamicList"
                  "olcOverlayConfig"
                ];
                olcOverlay = "{0}dynlist";
                olcDlAttrSet = "groupOfURLs memberURL uniqueMember+memberOf@groupOfUniqueNames";
              };
              "olcOverlay={1}sssvlv".attrs = {
                objectClass = [
                  "olcSSSVLVConfig"
                  "olcOverlayConfig"
                ];
                olcOverlay = "{1}sssvlv";
              };
              "olcOverlay={2}ppolicy".attrs = {
                objectClass = [
                  "olcOverlayConfig"
                  "olcPPolicyConfig"
                ];
                olcOverlay = "{2}ppolicy";
                olcPPolicyDefault = "cn=default,ou=policies,dc=stura-ilmenau,dc=de";
                olcPPolicyHashCleartext = "TRUE";
                olcPPolicyForwardUpdates = "FALSE";
              };
            };
          };

          "olcDatabase={-1}frontend" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" "olcFrontendConfig" ];
              olcPasswordHash = "{ARGON2}";
              # No simple binds over plain ldap:// without StartTLS. TLS has an
              # SSF >= 128, ldapi:// 71, plain ldap:// 0.
              olcSecurity = "simple_bind=64";
            };
          };
        };
      };
    };

    /* ensure openldap is launched after certificates are created */
    systemd.services.openldap = {
      wants = [ "acme-${cfg.fqdn}.service" ];
      after = [ "acme-${cfg.fqdn}.service" ];
      # Takes a few seconds for our database size.
      serviceConfig.ExecStartPre = mkAfter [
        "${config.services.openldap.package}/bin/slapindex -q -F /etc/openldap/slapd.d -b ${suffix}"
      ];
    };

    systemd.services.openldap-service-accounts = mkIf (cfg.realms != {} || cfg.globalServices != {}) {
      description = "OpenLDAP service accounts";
      wantedBy = [ "multi-user.target" ];
      requires = [ "openldap.service" ];
      after = [ "openldap.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = syncServiceAccounts;
        # slapd may not accept connections right after its unit started.
        Restart = "on-failure";
        RestartSec = 5;
      };
      unitConfig.StartLimitBurst = 5;
    };

    /* make acme certificates accessible by openldap */
    security.acme.defaults.group = "certs";
    users.groups.certs.members = [ "openldap" ];

    /* trigger the actual certificate generation for your hostname */
    security.acme.certs."${cfg.fqdn}" = {
      extraDomainNames = [];
      listenHTTP = ":80";
    };

    # Must exist before the job starts, it's sandboxed (readWritePaths).
    systemd.tmpfiles.rules = [ "d /var/backup/openldap 0700 root root -" ];

    services.borgbackup.jobs.openldap = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./openldap";
      # Copying data.mdb while slapd writes isn't consistent, slapcat is.
      # Restore: slapadd -F /etc/openldap/slapd.d -b ${suffix} -l data.ldif
      # slapcat needs write access to the mdb lock file, even for reading.
      readWritePaths = [ "/var/backup/openldap" "/var/lib/openldap/data" ];
      preHook = ''
        (umask 077; ${config.services.openldap.package}/bin/slapcat -F /etc/openldap/slapd.d -b ${suffix} -l /var/backup/openldap/data.ldif.tmp)
        mv /var/backup/openldap/data.ldif.tmp /var/backup/openldap/data.ldif
      '';
      paths = [ "/var/backup/openldap/data.ldif" credentialsDir ];
      doInit = false;
      startAt = [ "*-*-* 05:00:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}

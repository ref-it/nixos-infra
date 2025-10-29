{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.openldap;
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
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [ 80 443 ];
      extraInputRules = ''
        ip saddr 10.170.20.104 tcp dport { 389, 636 } accept comment "miraculix"
        ip saddr 10.170.20.106 tcp dport { 389, 636 } accept comment "majestix"
        ip saddr 10.170.20.110 tcp dport { 389, 636 } accept comment "hephaistos"
        ip saddr 10.170.20.117 tcp dport { 389, 636 } accept comment "gelantine"
        ip6 saddr 2001:638:904:ffbe::190 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::191 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::192 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::193 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbf::54 tcp dport { 389, 636 } accept comment "web-2-manage"
        ip6 saddr 2001:638:904:ffd0::d tcp dport { 389, 636 } accept comment "klotho"
        ip6 saddr 2001:638:904:ffd0::12 tcp dport { 389, 636 } accept comment "obelix"
        ip6 saddr 2001:638:904:ffd0::13 tcp dport { 389, 636 } accept comment "majestix"
        ip6 saddr 2001:638:904:ffd0::14 tcp dport { 389, 636 } accept comment "hephaistos"
        ip6 saddr 2001:638:904:ffd0::15 tcp dport { 389, 636 } accept comment "miraculix"
      '';
    };

    sops.secrets = {
      "openldap-pw" = {
        owner = "openldap";
        group = "openldap";
        mode = "0400";
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
          olcLogLevel = "conns config";

          /* settings for acme ssl */
          olcTLSCACertificateFile = "/var/lib/acme/${cfg.fqdn}/full.pem";
          olcTLSCertificateFile = "/var/lib/acme/${cfg.fqdn}/cert.pem";
          olcTLSCertificateKeyFile = "/var/lib/acme/${cfg.fqdn}/key.pem";
          olcTLSCipherSuite = "HIGH:MEDIUM:+3DES:+RC4:+aNULL";
          olcTLSCRLCheck = "none";
          olcTLSVerifyClient = "never";
          olcTLSProtocolMin = "3.1";
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

              olcSuffix = "dc=stura-ilmenau,dc=de";

              olcRootDN = "cn=admin,dc=stura-ilmenau,dc=de";
              olcRootPW.path = config.sops.secrets."openldap-pw".path;

              olcAccess = [
                /* custom access rules for userPassword attributes */
                ''{0}to attrs=userPassword
                    by self write
                    by anonymous auth
                    by * none''

                /* allow read on anything else */
                ''{1}to *
                    by * read''
              ];
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
            };
          };

          "olcDatabase={-1}frontend" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" "olcFrontendConfig" ];
              olcPasswordHash = "{ARGON2}";
            };
          };
        };
      };
    };

    /* ensure openldap is launched after certificates are created */
    systemd.services.openldap = {
      wants = [ "acme-${cfg.fqdn}.service" ];
      after = [ "acme-${cfg.fqdn}.service" ];
    };

    /* make acme certificates accessible by openldap */
    security.acme.defaults.group = "certs";
    users.groups.certs.members = [ "openldap" ];

    /* trigger the actual certificate generation for your hostname */
    security.acme.certs."${cfg.fqdn}" = {
      extraDomainNames = [];
      listenHTTP = ":80";
    };

    services.borgbackup.jobs.openldap = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./openldap";
      paths = [ "/var/lib/openldap" ];
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

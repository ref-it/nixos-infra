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
      allowedTCPPorts = [ 80 ];
      extraInputRules = ''
        ip6 saddr 2001:638:904:ffbe::191 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::192 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffbe::193 tcp dport { 389, 636 } accept comment "web-2"
        ip6 saddr 2001:638:904:ffd0::13 tcp dport { 389, 636 } accept comment "majestix"
        ip6 saddr 2001:638:904:ffd0::15 tcp dport { 389, 636 } accept comment "miraculix"
      '';
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

          "olcDatabase={1}mdb" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];

              olcDatabase = "{1}mdb";
              olcDbDirectory = "/var/lib/openldap/data";

              olcSuffix = "dc=stura-ilmenau,dc=de";

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
                objectClass = [ "olcDynamicList" "olcOverlayConfig" ];
                olcOverlay = "{0}dynlist";
                olcDlAttrSet = "groupOfURLs memberURL uniqueMember+memberOf@groupOfUniqueNames";
              };
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
  };
}

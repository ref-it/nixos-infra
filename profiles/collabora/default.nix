{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.collabora;

  port = 9980;
  upstream = "http://[::1]:${toString port}";

  # Official Collabora CODE image, pinned in oci-images/collabora.json.
  ociImages = import ../../oci-images { inherit lib pkgs; };

  # WOPI hosts allowed to open documents, one alias group per host.
  hostUrl = h: if hasInfix ":" h then "https://[${h}]:443" else "https://${h}:443";
  aliasGroups = listToAttrs (imap1 (i: h: nameValuePair "aliasgroup${toString i}" (hostUrl h)) cfg.trustedHosts);

  proxy = extra: {
    proxyPass = upstream;
    extraConfig = ''
      proxy_set_header Host $host;
    '' + extra;
  };
  wsProxy = proxy ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_read_timeout 36000s;
  '';
in
{
  options.profiles.collabora = {
    enable = mkEnableOption (mdDoc "Enable the Collabora profile");

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of Collabora.
      '';
    };

    trustedHosts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = mdDoc ''
        List of hosts allowed to access Collabora Online.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    virtualisation.oci-containers.containers.collabora = {
      inherit (ociImages.collabora) image imageFile;
      environment = aliasGroups // {
        server_name = cfg.fqdn;
        DONT_GEN_SSL_CERT = "1";
        extra_params = concatStringsSep " " [
          "--o:ssl.enable=false"
          "--o:ssl.termination=true"
          # Host network (below): only reachable through nginx on this host.
          "--o:net.listen=loopback"
          "--o:remote_font_config.url=https://cloud.stura-ilmenau.de/apps/richdocuments/settings/fonts.json"
        ];
      };
      # Needed by coolwsd to set up its document jails.
      # Host network so WOPI requests to Nextcloud come from the host's own
      # address, which is what richdocuments' wopi_allowlist contains. On the
      # podman bridge they'd come from 10.88.0.x and get a 403.
      extraOptions = [
        "--cap-add=MKNOD"
        "--network=host"
        # The image's probe ignores extra_params and checks
        # https://127.0.0.1:9980, but we serve plain HTTP on [::1] only.
        ''--health-cmd=["/usr/bin/coolwsd","--probe","--o:ssl.enable=false","--o:net.proto=IPv6"]''
      ];
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."${cfg.fqdn}" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "^~ /browser" = proxy "" // { priority = 10; };
          "^~ /hosting/discovery" = proxy "" // { priority = 20; };
          "^~ /hosting/capabilities" = proxy "" // { priority = 30; };
          "~ ^/cool/(.*)/ws$" = wsProxy // { priority = 40; };
          "~ ^/(c|l)ool" = proxy "" // { priority = 50; };
          "^~ /cool/adminws" = wsProxy // { priority = 60; };
        };
      };
    };
  };
}

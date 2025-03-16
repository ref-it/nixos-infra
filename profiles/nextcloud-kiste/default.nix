{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.nextcloud-kiste;
in
{
  options.profiles.nextcloud-kiste = {
    enable = mkEnableOption (mdDoc "Enable the Nextcloud (Kiste) profile");

    name = mkOption {
      type = types.str;
      description = mdDoc ''
        The name of the Nextcloud.
      '';
    };

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the Nextcloud (Kiste).
      '';
    };

    dir = mkOption {
      type = types.str;
      description = mdDoc ''
        Directory of the Nextcloud.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services = {
      postgresql = {
        enable = true;
        ensureDatabases = [ "${cfg.name}" ];
        authentication = pkgs.lib.mkOverride 10 ''
          #type database  DBuser  auth-method
          local sameuser  all     trust
        '';
      };

      phpfpm.pools.${cfg.name} = {
        user = cfg.name;
        settings = {
          "listen.owner" = config.services.nginx.user;
          "pm" = "dynamic";
          "pm.max_children" = 32;
          "pm.max_requests" = 500;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 5;
          "php_admin_value[error_log]" = "stderr";
          "php_admin_flag[log_errors]" = true;
          "catch_workers_output" = true;
        };
        phpOptions = ''
          extension=${pkgs.phpExtensions.redis}/lib/php/extensions/redis.so
          extension=${pkgs.phpExtensions.apcu}/lib/php/extensions/apcu.so
        '';
        phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
      };

      nginx = {
        enable = true;
        virtualHosts = {
          ${cfg.fqdn} = {
            root = "${cfg.dir}/nextcloud";
            forceSSL = true;
            enableACME = true;
            locations = {
              "= /" = {
                extraConfig = ''
                  if ( $http_user_agent ~ ^DavClnt ) {
                    return 302 /remote.php/webdav/$is_args$args;
                  }
                '';
              };

              "^~ /.well-known" = {
                extraConfig = ''
                  location = /.well-known/carddav { return 301 /remote.php/dav/; }
                  location = /.well-known/caldav  { return 301 /remote.php/dav/; }

                  location /.well-known/acme-challenge { try_files $uri $uri/ =404; }
                  location /.well-known/pki-validation { try_files $uri $uri/ =404; }

                  # Let Nextcloud's API for `/.well-known` URIs handle all other
                  # requests by passing them to the front-end controller.
                  return 301 /index.php$request_uri;
                '';
              };

              "~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)" = {
                return = "404";
              };

              "~ ^/(?:\.|autotest|occ|issue|indie|db_|console)" = {
                return = "404";
              };

              "~ \.php(?:$|/)" = {
                extraConfig = ''
                  rewrite ^/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|ocs-provider\/.+|.+\/richdocumentscode(_arm64)?\/proxy) /index.php$request_uri;

                  fastcgi_split_path_info ^(.+?\.php)(/.*)$;
                  set $path_info $fastcgi_path_info;

                  try_files $fastcgi_script_name =404;

                  include fastcgi_params;
                  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                  fastcgi_param PATH_INFO $path_info;
                  fastcgi_param HTTPS on;

                  fastcgi_param modHeadersAvailable true;         # Avoid sending the security headers twice
                  fastcgi_param front_controller_active true;     # Enable pretty urls
                  fastcgi_pass php-handler;

                  fastcgi_intercept_errors on;
                  fastcgi_request_buffering off;

                  fastcgi_max_temp_file_size 0;
                '';
              };

              "~ \.(?:css|js|mjs|svg|gif|ico|jpg|png|webp|wasm|tflite|map|ogg|flac)$" = {
                extraConfig = ''
                  try_files $uri /index.php$request_uri;
                  # HTTP response headers borrowed from Nextcloud `.htaccess`
                  add_header Cache-Control                     "public, max-age=15778463$asset_immutable";
                  add_header Referrer-Policy                   "no-referrer"       always;
                  add_header X-Content-Type-Options            "nosniff"           always;
                  add_header X-Frame-Options                   "SAMEORIGIN"        always;
                  add_header X-Permitted-Cross-Domain-Policies "none"              always;
                  add_header X-Robots-Tag                      "noindex, nofollow" always;
                  add_header X-XSS-Protection                  "1; mode=block"     always;
                  access_log off;     # Optional: Don't log access to assets
                '';
              };

              "~ \.(otf|woff2?)$" = {
                tryFiles = "$uri /index.php$request_uri";
                extraConfig = ''
                  expires 7d;         # Cache-Control policy borrowed from `.htaccess`
                  access_log off;     # Optional: Don't log access to assets
                '';
              };

              "/remote" = {
                return = "301 /remote.php$request_uri";
              };

              "/" = {
                tryFiles = "$uri $uri/ /index.php$request_uri";
              };
            };
          };
        };
      };
    };

    sops.secrets = {
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    users = {
      users.${cfg.name} = {
        isSystemUser = true;
        createHome = true;
        home = cfg.dir;
        group = cfg.name;
      };
      groups.${cfg.name} = {};
    };

    environment.systemPackages = [
      pkgs.unzip
    ];
  };
}

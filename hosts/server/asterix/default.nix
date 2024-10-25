{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    system.stateVersion = "23.05";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "asterix";

    base.primaryIP = "2001:638:904:ffd0::28";

    systemd.network = {
      enable = true;
      networks = {
        "40-ens18" = {
          name = "ens18";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "2001:638:904:ffd0::28/64"
          ];
          gateway = [
            "2001:638:904:ffd0::1"
          ];
        };
        "50-ens19" = {
          name = "ens19";
          networkConfig = {
            IPv6AcceptRA = false;
          };
          address = [
            "10.170.20.108/24"
          ];
          gateway = [
            "10.170.20.1"
          ];
        };
      };
    };

    sops.defaultSopsFile = ./secrets.yaml;

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
      ensureDatabases = [ "typo3" ];
      authentication = pkgs.lib.mkOverride 10 ''
        #type database  DBuser  auth-method
        local sameuser  all     peer
      '';
    };

    services.phpfpm.pools."typo3" = {
      phpPackage = pkgs.php83;
      user = "typo3";
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
        "memory_limit" = "256M";
        "max_execution_time" = 240;
        "max_input_vars" = 1500;
        "pcre.jit" = 1;
      };
      phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
    };

    services.nginx = {
      enable = true;
      user = "typo3";
      virtualHosts = {
        "new.stura-ilmenau.de" = {
          serverName = "new.stura-ilmenau.de";
          serverAliases = [
            "new.erstiwoche.de"
            "new.fsr-ia.de"
            "new.fsr-wm.de"
            "new.promovertretung.de"
            "new.studierendenbeirat.de"
            "new.sap-ilmenau.de"
          ];
          root = "/var/typo3/public";
          forceSSL = true;
          enableACME = true;
          locations = {
            "~ \.js\.gzip$" = {
              extraConfig = ''
                add_header Content-Encoding gzip;
                gzip off;
                types { text/javascript gzip; }
              '';
            };
            "~ \.css\.gzip$" = {
              extraConfig = ''
                add_header Content-Encoding gzip;
                gzip off;
                types { text/css gzip; }
              '';
            };
            "~* composer\.(?:json|lock)" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~* flexform[^.]*\.xml" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~* locallang[^.]*\.(?:xml|xlf)$" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~* ext_conf_template\.txt|ext_typoscript_constants\.txt|ext_typoscript_setup\.txt" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~* /.*\.(?:bak|co?nf|cfg|ya?ml|ts|typoscript|tsconfig|dist|fla|in[ci]|log|sh|sql|sqlite)$" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~ _(?:recycler|temp)_/" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~ fileadmin/(?:templates)/.*\.(?:txt|ts|typoscript)$" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~ ^(?:vendor|typo3_src|typo3temp/var)" = {
              extraConfig = ''
                deny all;
              '';
            };
            "~ (?:typo3conf/ext|typo3/sysext|typo3/ext)/[^/]+/(?:Configuration|Resources/Private|Tests?|Documentation|docs?)/" = {
              extraConfig = ''
                deny all;
              '';
            };
            "/" = {
              tryFiles = "$uri $uri/ /index.php$is_args$args";
            };
            "/typo3" = {
              extraConfig = ''
                rewrite ^ /typo3/;
              '';
            };
            "/typo3/" = {
              extraConfig = ''
                absolute_redirect off;
              '';
              tryFiles = "$uri /typo3/index.php$is_args$args";
            };
            "~ [^/]\.php(/|$)" = {
              extraConfig = ''
                fastcgi_split_path_info ^(.+?\.php)(/.*)$;
                if (!-f $document_root$fastcgi_script_name) {
                    return 404;
                }
                fastcgi_buffer_size 32k;
                fastcgi_buffers 8 16k;
                fastcgi_connect_timeout 240s;
                fastcgi_read_timeout 240s;
                fastcgi_send_timeout 240s;
                fastcgi_index index.php;

                fastcgi_pass unix:${config.services.phpfpm.pools."typo3".socket};
                include ${pkgs.nginx}/conf/fastcgi.conf;
              '';
            };
          };
          extraConfig = ''
            if (!-e $request_filename) {
                rewrite ^/(.+)\.(\d+)\.(php|js|css|png|jpg|gif|gzip)$ /$1.$3 last;
            }
          '';
        };
      };
    };

    users.users."typo3" = {
      isSystemUser = true;
      createHome = true;
      home = "/var/typo3";
      group = "typo3";
    };
    users.groups."typo3" = {};
  };
}

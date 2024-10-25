{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.profiles.desktop-plasma6;
in
{
  options.profiles.desktop-playma6 = {
    enable = mkEnableOption (mdDoc "Enable the KDE Plasma 6 profile");
  };

  config = mkIf cfg.enable {
    
    services = {
      xserver.enable = true;
      displayManager = {
        sddm.enable = true;
        defaultSession = "plasma";
      };
      desktopManager.plasma6.enable = true;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };

    security.rtkit.enable = true; # optional but recommended for PipeWire, see https://nixos.wiki/wiki/PipeWire

    environment = {
      systemPackages = with pkgs; [
        audacity
        chromium
        cups-kyodialog
        filezilla
        firefox
        gimp
        hunspell
        hunspellDicts.de_DE
        hunspellDicts.en_US
        inkscape
        jabref
        keepassxc
        libreoffice-qt6-fresh
        nextcloud-client
        obs-studio
        scribus
        spotify
        telegram-desktop
        texstudio
        thunderbird
        vlc
        vscode
      ];
      plasma6.excludePackages = with pkgs.kdePackages; [
        oxygen
      ];
    };

    programs = {
      chromium = {
        enable = true;
        extensions = [
          "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
          "oboonakemofpalcgghocfoadofidjkkk" # KeePassXC
        ];
        enablePlasmaBrowserIntegration = true;
        homepageLocation = "https://hub.stura-ilmenau.de/";
      };
      firefox = {
        enable = true;
        languagePacks = [
          "de"
          "en-US"
        ];
        nativeMessagingHosts.packages = [
          pkgs.plasma5Packages.plasma-browser-integration
        ];
        policies = {
          DisableTelemetry = true;
          DisableFirefoxStudies = true;
          EnableTrackingProtection = {
            Value= true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
          };
          DisablePocket = true;
          DisableFirefoxAccounts = true;
          DisableAccounts = true;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
          DisplayBookmarksToolbar = "never";
          DisplayMenuBar = "never";
          SearchBar = "unified";

          ExtensionSettings = {
            "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
            # uBlock Origin
            "uBlock0@raymondhill.net" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
              installation_mode = "force_installed";
            };
            # KeePassXC
            "keepassxc-browser@keepassxc.org" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/keepassxc_browser/latest.xpi";
              installation_mode = "force_installed";
            };
            # Plasma Browser Integration
            "plasma-browser-integration@kde.org" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/plasma_integration/latest.xpi";
              installation_mode = "force_installed";
            };
            # Breeze Light Theme
            "{185828ca-ea6c-4dd8-8d32-0f941b3f1bd7}" = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/breezelighttheme/latest.xpi";
              installation_mode = "force_installed";
            };
          };
    
          Preferences = { 
            "browser.startup.homepage" = "https://hub.stura-ilmenau.de/";
            "browser.tabs.closeWindowWithLastTab" = lock-false;
            "extensions.pocket.enabled" = lock-false;
            "browser.topsites.contile.enabled" = lock-false;
            "browser.formfill.enable" = lock-false;
            "browser.search.suggest.enabled" = lock-false;
            "browser.search.suggest.enabled.private" = lock-false;
            "browser.urlbar.suggest.searches" = lock-false;
            "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
            "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
            "browser.newtabpage.activity-stream.showSponsored" = lock-false;
            "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;
            "dom.private-attribution.submission.enabled" = lock-false;
            "widget.use-xdg-desktop-portal.file-picker" = 1;
          };
        };
      };
    };


    sops.secrets = {
      "nc-init-pw" = {
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0400";
      };
      "borg-passphrase" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    systemd.services.nextcloud-setup.after = [ "mysql.service" ];

    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud29;
      https = true;
      hostName = cfg.fqdn;
      autoUpdateApps.enable = true;
      configureRedis = true;
      maxUploadSize = "2048M";
      phpOptions = {
        "opcache.interned_strings_buffer" = "64";
        "opcache.memory_consumption" = "1024";
      };
      settings = {
        trusted_domains = cfg.extraDomains;
        maintenance_window_start = "2";
        trusted_proxies = cfg.trustedProxies;
        default_phone_region = "DE";
        sharing.enable_share_accept = false;
        sharing.force_share_accept = false;
      };
      config = {
        dbtype = "mysql";
        dbname = "nextcloud";
        dbuser = "nextcloud";
        adminuser = "admin";
        adminpassFile = config.sops.secrets."nc-init-pw".path;
        dbhost = "localhost:/run/mysqld/mysqld.sock";
      };
    };

    services.borgbackup.jobs.nextcloud = {
      user = "root";
      group = "root";
      repo = "ssh://backup:23/./cloud";
      readWritePaths = [ "/var/lib/nextcloud/db-backup" ];
      preHook = ''
        cd /var/lib/nextcloud

        rm -f db-backup/*

        ${pkgs.mariadb}/bin/mysqldump ${config.services.nextcloud.config.dbname} > db-backup/${config.services.nextcloud.config.dbname}.sql
      '';
      paths = [ "config/config.php" "data" "db-backup" ];
      doInit = false;
      startAt = [ "*-*-* 04:00:00" ];
      encryption.mode = "repokey";
      encryption.passCommand = "cat ${config.sops.secrets."borg-passphrase".path}";
      prune.keep.within = "1y";
      compression = "auto,zstd";
      dateFormat = "+%Y-%m-%d";
      archiveBaseName = "backup";
    };
  };
}

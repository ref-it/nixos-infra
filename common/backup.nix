{ config, lib, pkgs, ... }:

# Target of the borgbackup jobs (repo = "ssh://backup:23/./<name>"): one
# Storage Box sub-account per host. Account names stay out of this public
# repo, they come from the host's sops secret:
#
#   borg-ssh-config: |
#     Host backup
#       HostName <box>.your-storagebox.de
#       User <box>-sub<N>
#
# The SSH key is generated on the host. Install it once for the sub-account
# (asks for the sub-account's password):
#   sudo ssh-copy-id -p 23 -s -i /var/lib/borg-ssh/id_ed25519.pub backup
#
# Failure notification: a failed borg job or database dump sends a mail to
# base.backupMail.to, and a daily check mails when a job hasn't succeeded for
# more than a day (catches jobs that never ran). The SMTP password of
# base.backupMail.from comes from the host's sops secret "backup-mail-password".

with lib;

let
  keyDir = "/var/lib/borg-ssh";
  keyFile = "${keyDir}/id_ed25519";

  jobs = config.services.borgbackup.jobs;
  pgBackup = config.services.postgresqlBackup;
  mailCfg = config.base.backupMail;
  hostName = config.networking.hostName;
  statusDir = "/var/lib/backup-status";

  # postgresqlBackup dumps a job backs up, as database names.
  jobDumps = job:
    let
      prefix = "${pgBackup.location}/";
      isDump = p: hasPrefix prefix p && hasSuffix ".sql.gz" p;
      dbOf = p: removeSuffix ".sql.gz" (removePrefix prefix p);
    in
    optionals (pgBackup.enable && !pgBackup.backupAll && job.paths != null)
      (filter (db: elem db pgBackup.databases) (map dbOf (filter isDump (toList job.paths))));

  # Usage: backup-mail <subject>, body on stdin.
  sendMail = pkgs.writeShellScript "backup-mail" ''
    {
      echo "From: ${mailCfg.from}"
      echo "To: ${mailCfg.to}"
      echo "Subject: [${hostName}] $1"
      echo "Content-Type: text/plain; charset=UTF-8"
      echo
      cat
    } | ${pkgs.msmtp}/bin/msmtp -a backup ${escapeShellArg mailCfg.to}
  '';

  # borg treats missing paths only as a warning, and the dump runs on its own
  # timer, so without this a failed dump would silently back up an old one.
  checkDumps = name: dbs: pkgs.writeShellScript "borgbackup-${name}-check-dumps" ''
    for f in ${concatMapStringsSep " " (db: escapeShellArg "${pgBackup.location}/${db}.sql.gz") dbs}; do
      if [ -z "$(${pkgs.findutils}/bin/find "$f" -mmin -360 2>/dev/null)" ]; then
        echo "$f is missing or older than 6 hours, the database dump failed" >&2
        exit 1
      fi
    done
  '';
in
{
  options.base.backupMail = {
    to = mkOption {
      type = types.str;
      default = "it@stura-ilmenau.de";
      description = "Recipient of backup failure mails.";
    };
    from = mkOption {
      type = types.str;
      default = "monitoring@stura.tu-ilmenau.de";
      description = "Sender and SMTP login of backup failure mails.";
    };
    smtpHost = mkOption {
      type = types.str;
      default = "imap.fem.tu-ilmenau.de";
      description = "SMTP server (port 587, STARTTLS) for backup failure mails.";
    };
  };

  config = mkIf (jobs != {}) {
    # Included by the system ssh_config, so it must be readable by every
    # user running ssh. Contains no credentials.
    sops.secrets."borg-ssh-config".mode = "0444";

    programs.ssh.extraConfig = ''
      Include ${config.sops.secrets."borg-ssh-config".path}
      Host backup
        Port 23
        IdentityFile ${keyFile}
        IdentitiesOnly yes
        HostKeyAlias storagebox
    '';

    programs.ssh.knownHosts.storagebox = {
      hostNames = [ "storagebox" "[storagebox]:23" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
    };

    systemd.services = {
      borg-ssh-key = {
        description = "SSH key for borgbackup";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          install -d -m 0700 ${keyDir}
          if [ ! -e ${keyFile} ]; then
            ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "borg@${config.networking.hostName}" -f ${keyFile}
          fi
        '';
      };

      "backup-failure-mail@" = {
        description = "Mail about failed backup unit %i";
        serviceConfig.Type = "oneshot";
        scriptArgs = "%i";
        script = ''
          { echo "$1 failed on ${hostName}."; echo; journalctl -u "$1" -n 100 --no-pager; } \
            | ${sendMail} "Backup failed: $1"
        '';
      };

      backup-stale-check = {
        description = "Mail about backup jobs without recent success";
        serviceConfig.Type = "oneshot";
        script = ''
          stale=""
          for job in ${concatStringsSep " " (attrNames jobs)}; do
            if [ -z "$(${pkgs.findutils}/bin/find ${statusDir}/"$job" -mmin -1560 2>/dev/null)" ]; then
              stale="$stale $job"
            fi
          done
          if [ -n "$stale" ]; then
            echo "No successful run within the last 26 hours:$stale" \
              | ${sendMail} "Backup overdue:$stale"
          fi
        '';
      };
    } // mapAttrs' (name: job: nameValuePair "borgbackup-job-${name}" {
      requires = [ "borg-ssh-key.service" ];
      # Waits for a dump that is still running when the job starts.
      after = [ "borg-ssh-key.service" ] ++ map (db: "postgresqlBackup-${db}.service") (jobDumps job);
      onFailure = [ "backup-failure-mail@%n.service" ];
      serviceConfig = {
        ExecStartPre = optional (jobDumps job != []) (checkDumps name (jobDumps job));
        # "+": outside the job's ProtectSystem=strict sandbox.
        ExecStartPost = "+${pkgs.coreutils}/bin/touch ${statusDir}/${name}";
      };
    }) jobs // optionalAttrs (pgBackup.enable && !pgBackup.backupAll) (listToAttrs (map (db:
      nameValuePair "postgresqlBackup-${db}" {
        onFailure = [ "backup-failure-mail@%n.service" ];
      }) pgBackup.databases));

    systemd.timers.backup-stale-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "09:00";
        Persistent = true;
      };
    };

    # "f" creates a fresh stamp only if missing, so a newly added job gets a
    # day of grace before the stale check complains.
    systemd.tmpfiles.rules = [ "d ${statusDir} 0755 root root -" ]
      ++ map (name: "f ${statusDir}/${name} 0644 root root -") (attrNames jobs);

    sops.secrets."backup-mail-password".mode = "0400";

    programs.msmtp = {
      enable = true;
      setSendmail = false;
      accounts.backup = {
        host = mailCfg.smtpHost;
        port = 587;
        tls = true;
        tls_starttls = true;
        auth = true;
        user = mailCfg.from;
        from = mailCfg.from;
        passwordeval = "cat ${config.sops.secrets."backup-mail-password".path}";
      };
    };
  };
}

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

with lib;

let
  keyDir = "/var/lib/borg-ssh";
  keyFile = "${keyDir}/id_ed25519";
in
{
  config = mkIf (config.services.borgbackup.jobs != {}) {
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
    } // mapAttrs' (name: _: nameValuePair "borgbackup-job-${name}" {
      requires = [ "borg-ssh-key.service" ];
      after = [ "borg-ssh-key.service" ];
    }) config.services.borgbackup.jobs;
  };
}

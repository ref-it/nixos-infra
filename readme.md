# StuRa NixOS Infrastructure

Our servers are managed using the NixOS deployment tool [Colmena](https://github.com/zhaofengli/colmena).
Secrets are encrypted using [SOPS](https://github.com/mozilla/sops) and [age](https://github.com/FiloSottile/age) keys derived from SSH keys.

## Repo structure
```
.
├── flake.lock
├── flake.nix
├── hive.nix     # contains the definition of all our machines
├── common       # contains our common configurations and users
├── hosts        # contains our host-specific configuration (hostname, network, etc.)
├── profiles     # contains our profiles that we apply on hosts
├── oci-images   # OCI container images pinned by digest (one <name>.json each)
```

## Preparations

Currently you need to enable the experimental features "nix-command" and "flakes" in your nix daemon.

Then you can start a developer-shell using `nix develop` or use direnv to automatically drop into a developer shell when
entering the repository by running `echo "use flake" > .envrc && direnv allow`

## Build/Deployment

Some Examples:

- Build all hosts: `colmena build`
- Build & deploy a specific host: `colmena apply --on hostname`

## Updating

- NixOS packages: `nix flake update`
- OCI container images (`oci-images/*.json`): `./update-oci-images.sh` inside `nix develop`.
  It pins every image to its newest tag matching the image's `tagPattern`.
  `./update-oci-images.sh <name> [tag]` updates a single image, optionally to an exact tag.
  See the header of the script for how to add a new image.

Then review the diff and deploy as usual.

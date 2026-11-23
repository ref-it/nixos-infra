# OCI images pinned by digest, one <name>.json per image. Update them with
# ./update-oci-images.sh in the repo root.
#
# Usage in a profile:
#   ociImages = import ../../oci-images { inherit lib pkgs; };
#   virtualisation.oci-containers.containers.foo = {
#     inherit (ociImages.foo) image imageFile;
#   };
{ lib, pkgs }:

let
  # Keys that only update-oci-images.sh reads; pullImage rejects them.
  scriptOnly = [ "tagPattern" ];

  load = file:
    let
      pin = lib.importJSON (./. + "/${file}");
    in {
      image = "${pin.finalImageName}:${pin.finalImageTag}";
      imageFile = pkgs.dockerTools.pullImage (removeAttrs pin scriptOnly);
    };

  files = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".json" n) (builtins.readDir ./.);
in
lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".json" file) (load file)) files

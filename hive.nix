inputs:

{
  meta = {
    description = "StuRa Ilmenau nixfiles";

    overlays = [
      (final: prev: let
        unstable = import inputs.nixpkgs-unstable { inherit (prev.stdenv.hostPlatform) system; };
      in { inherit (unstable) lauti pretix zammad; })
    ];

    specialArgs = { inherit inputs; };
  };

  defaults = ./common;

  # Hosts (Server)
  # asterix = ./hosts/server/asterix;
  automatix = ./hosts/server/automatix;
  grautvornix = ./hosts/server/grautvornix;
  griesgramix = ./hosts/server/griesgramix;
  gutemine = ./hosts/server/gutemine;
  idefix = ./hosts/server/idefix;
  majestix = ./hosts/server/majestix;
  miraculix = ./hosts/server/miraculix;
  obelix = ./hosts/server/obelix;
  rohrpostix = ./hosts/server/rohrpostix;
  troubadix = ./hosts/server/troubadix;
  verliernix = ./hosts/server/verliernix;

  # Hosts (Desktop)
  # luchs = ./hosts/desktop/luchs;
  # igel = ./hosts/desktop/igel;
}

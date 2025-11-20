inputs:

{
  meta = {
    description = "StuRa Ilmenau nixfiles";

    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = [
        (final: prev: { inherit (import inputs.nixpkgs-unstable { system = prev.system; }) opencloud; })
        (final: prev: { inherit (import inputs.nixpkgs-unstable { system = prev.system; }) pretix; })
        (final: prev: { inherit (import inputs.nixpkgs-unstable { system = prev.system; }) vaultwarden; })
      ];
    };

    specialArgs = { inherit inputs; };
  };

  defaults = ./common;

  # Hosts (Server)
  # asterix = ./hosts/server/asterix;
  automatix = ./hosts/server/automatix;
  barometrix = ./hosts/server/barometrix;
  gelantine = ./hosts/server/gelantine;
  grautvornix = ./hosts/server/grautvornix;
  gutemine = ./hosts/server/gutemine;
  majestix = ./hosts/server/majestix;
  miraculix = ./hosts/server/miraculix;
  moralelastix = ./hosts/server/moralelastix;
  obelix = ./hosts/server/obelix;
  rohrpostix = ./hosts/server/rohrpostix;
  troubadix = ./hosts/server/troubadix;
  verliernix = ./hosts/server/verliernix;

  # Hosts (Desktop)
  # luchs = ./hosts/desktop/luchs;
  # igel = ./hosts/desktop/igel;
}

inputs:

{
  meta = {
    description = "StuRa Ilmenau nixfiles";

    nixpkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = [
        (final: prev: { inherit (import inputs.nixpkgs-unstable { system = prev.system; }) zammad; })
        (final: prev: { inherit (import inputs.nixpkgs-linkwarden { system = prev.system; }) linkwarden; })
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
  obelix = ./hosts/server/obelix;
  rohrpostix = ./hosts/server/rohrpostix;
  #sputnix = ./hosts/server/sputnix;
  troubadix = ./hosts/server/troubadix;

  # Hosts (Desktop)
  # luchs = ./hosts/desktop/luchs;
  # igel = ./hosts/desktop/igel;


  # bergmolch = ./hosts/raspi/bergmolch;
}

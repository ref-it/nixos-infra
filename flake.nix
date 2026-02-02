{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    sops.url = "github:Mic92/sops-nix";
    sops.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, colmena, sops, flake-utils, ... }@inputs: {

    colmena = import ./hive.nix inputs;
    colmenaHive = colmena.lib.makeHive self.outputs.colmena;
    nixosConfigurations = (self.outputs.colmenaHive).nodes;

  } // flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.default = pkgs.mkShell {
      name = "stura-nixfiles-shell";
      buildInputs = [
        sops.nixosModules.sops
        colmena.defaultPackage.${system}
        pkgs.ssh-to-age
      ];
    };
  });
}

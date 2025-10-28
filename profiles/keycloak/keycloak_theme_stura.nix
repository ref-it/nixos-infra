{ stdenv }:
stdenv.mkDerivation rec {
    name = "keycloak_theme_stura";
    version = "1.0";

    src = ./theme_stura;

    nativeBuildInputs = [ ];
    buildInputs = [ ];

    installPhase = ''
        mkdir -p $out
        cp -a login $out
    '';
}
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  name = "podfather";
  version = "0.1.1";
in
  buildGoModule {
    pname = name;
    inherit version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = name;
      rev = "v${version}";
      hash = "sha256-YIutnwp8F7OWDb/lotLPy6wR2f0bhD7vBOHQC6QYhEg=";
    };

    vendorHash = null;

    meta = {
      description = " A simple web dashboard for Podman 🦭 ";
      homepage = "https://github.com/jo-m/${name}";
      license = lib.licenses.mit;
      mainProgram = name;
    };
  }

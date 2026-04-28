{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  name = "podfather";
  version = "0.1.5";
in
  buildGoModule {
    pname = name;
    inherit version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = name;
      rev = "v${version}";
      hash = "sha256-N95GoOhQK8XwLGIJdR69sOvYuKw1dVI8z0gMgl+JE2A=";
    };

    vendorHash = null;

    meta = {
      description = " A simple web dashboard for Podman 🦭 ";
      homepage = "https://github.com/jo-m/${name}";
      license = lib.licenses.mit;
      mainProgram = name;
    };
  }

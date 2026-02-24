{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  name = "podfather";
  version = "0.1.3";
in
  buildGoModule {
    pname = name;
    inherit version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = name;
      rev = "v${version}";
      hash = "sha256-q6zkyNny1sLnU/8f9z7vQLB8coYMGPmhYNFM3Bdj9xc=";
    };

    vendorHash = null;

    meta = {
      description = " A simple web dashboard for Podman 🦭 ";
      homepage = "https://github.com/jo-m/${name}";
      license = lib.licenses.mit;
      mainProgram = name;
    };
  }

{
  lib,
  buildGoModule,
  fetchFromGitHub,
}: let
  name = "podfather";
  version = "0.1.2";
in
  buildGoModule {
    pname = name;
    inherit version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = name;
      rev = "v${version}";
      hash = "sha256-LfjqIac3+8R+qx6yY/hwC93RgcAgZ6J1uzEpDnQgKcc=";
    };

    vendorHash = null;

    meta = {
      description = " A simple web dashboard for Podman 🦭 ";
      homepage = "https://github.com/jo-m/${name}";
      license = lib.licenses.mit;
      mainProgram = name;
    };
  }

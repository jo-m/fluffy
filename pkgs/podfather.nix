{
  lib,
  buildGoModule,
  go_1_27,
  fetchFromGitHub,
}: let
  name = "podfather";
  version = "0.1.6";
in
  # TODO: Remove the override once nixpkgs default Go is new enough.
  (buildGoModule.override {go = go_1_27;}) {
    pname = name;
    inherit version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = name;
      rev = "v${version}";
      hash = "sha256-ld72WIe5KebVloHQ3ku0Y/nOJvewWDh4w81UTGbp4EE=";
    };

    vendorHash = null;

    meta = {
      description = " A simple web dashboard for Podman 🦭 ";
      homepage = "https://github.com/jo-m/${name}";
      license = lib.licenses.mit;
      mainProgram = name;
    };
  }

{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule {
  pname = "podfather";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "jo-m";
    repo = "podfather";
    rev = "v0.1.0";
    hash = "sha256-zjF/OvgXky4D96YSIEXEGBQ84gEr7fOA9oxYBIA50hE=";
  };

  vendorHash = null;

  meta = {
    description = " A simple web dashboard for Podman 🦭 ";
    homepage = "https://github.com/jo-m/podfather";
    license = lib.licenses.mit;
    mainProgram = "podfather";
  };
}

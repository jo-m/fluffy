{
  lib,
  # go.mod requires Go >= 1.26.3; use the matching builder.
  buildGo126Module,
  fetchFromGitHub,
}: let
  pname = "fogdb";
  # Upstream has no tagged releases; pin to a specific commit on main.
  version = "0-unstable-2026-05-21";
  rev = "fe44c91309374467305372671e05963a707aa52a";
in
  buildGo126Module {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = "fogDB";
      inherit rev;
      hash = "sha256-0hyPKT67cls3WktlKfHc9AYbtamPwK87JjONFhyS2Xk=";
    };

    vendorHash = "sha256-KYN1DK5yUAZi1/n1/x+B7T65/+zavrku2aCqamMff9w=";

    # Only build the main binary; skip lint/test tooling listed in go.mod's `tool` block.
    subPackages = ["."];

    meta = {
      description = "Long-running ingester for MeteoSwiss point-forecast CSVs into a local SQLite archive";
      homepage = "https://github.com/jo-m/fogDB";
      license = lib.licenses.mit;
      mainProgram = pname;
      platforms = lib.platforms.linux;
    };
  }

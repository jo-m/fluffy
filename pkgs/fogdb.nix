{
  lib,
  # go.mod requires Go >= 1.26.3; use the matching builder.
  buildGo126Module,
  fetchFromGitHub,
}: let
  pname = "fogdb";
  # Upstream has no tagged releases; pin to a specific commit on main.
  version = "0-unstable-2026-11-01";
  rev = "f155ec992f708bce788dddf59103fc94c3d1923e";
in
  buildGo126Module {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = "fogDB";
      inherit rev;
      hash = "sha256-0ZFoYEuWpnfrxhkhjJlCIBlxNOxtHesz1M0F3n9cJEI=";
    };

    vendorHash = "sha256-ZRMNb2sVSi8UoCBX5jz17kZ2WUcRhg8twyYF6IyOejQ=";

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

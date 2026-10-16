{
  lib,
  # go.mod requires Go >= 1.26.3; use the matching builder.
  buildGo126Module,
  fetchFromGitHub,
}: let
  pname = "fogdb";
  # Upstream has no tagged releases; pin to a specific commit on main.
  version = "0-unstable-2026-10-16";
  rev = "48a1b408bee249eaa6ef416d0ba478bc17453a4d";
in
  buildGo126Module {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "jo-m";
      repo = "fogDB";
      inherit rev;
      hash = "sha256-rSjjmKX5YhbZLoR9l0ldwX4zBqDnu2gNOxWj4KjTBrE=";
    };

    vendorHash = "sha256-SgXinTQ/0xJv5b1dbfdzKPdw7cIEYrY3LlfmU0vhTSI=";

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

{pkgs}: let
  format = pkgs.writeShellScriptBin "format" ''
    set -xeou pipefail

    nix fmt .
  '';

  lint = pkgs.writeShellScriptBin "lint" ''
    set -xeou pipefail

    shopt -s globstar
    ${pkgs.nixf-diagnose}/bin/nixf-diagnose ./**/*.nix
    ${pkgs.statix}/bin/statix check .
    ${pkgs.deadnix}/bin/deadnix --fail .
  '';

  fix = pkgs.writeShellScriptBin "fix" ''
    set -xeou pipefail

    ${pkgs.statix}/bin/statix fix .
    ${pkgs.deadnix}/bin/deadnix --edit .
    nix fmt .
  '';
in
  pkgs.symlinkJoin {
    name = "scripts";
    paths = [
      format
      lint
      fix
    ];
  }

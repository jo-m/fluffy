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

  diff-versions = pkgs.writeShellScriptBin "diff-versions" ''
    set -euo pipefail

    if [[ $# -lt 1 || $# -gt 2 ]]; then
      echo "Usage: diff-versions <commit-a> [commit-b]" >&2
      echo "  If commit-b is omitted, defaults to the currently checked out ref." >&2
      exit 1
    fi

    commit_a="$1"
    commit_b="''${2:-HEAD}"

    repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"

    strip_hashes() {
      ${pkgs.gnused}/bin/sed 's|/nix/store/[a-z0-9]\{32\}-||' | sort -u
    }

    build_and_list() {
      local commit="$1"
      local label="$2"
      local resolved
      resolved="$(${pkgs.git}/bin/git rev-parse --short "$commit")"

      echo "Building toplevel for ''${label} (''${commit} -> ''${resolved})..." >&2
      local drv
      drv="$(nix build "''${repo_root}?rev=$(${pkgs.git}/bin/git rev-parse "$commit")#nixosConfigurations.fluffy.config.system.build.toplevel" \
        --no-link --print-out-paths 2>/dev/null)"

      echo "Querying closure for ''${label}..." >&2
      nix path-info --recursive "$drv" | strip_hashes
    }

    tmp_a="$(mktemp)"
    tmp_b="$(mktemp)"
    trap 'rm -f "$tmp_a" "$tmp_b"' EXIT

    build_and_list "$commit_a" "A" > "$tmp_a"
    build_and_list "$commit_b" "B" > "$tmp_b"

    short_a="$(${pkgs.git}/bin/git rev-parse --short "$commit_a")"
    short_b="$(${pkgs.git}/bin/git rev-parse --short "$commit_b")"

    echo ""
    echo "=== Package diff: ''${short_a} -> ''${short_b} ==="
    echo ""

    ${pkgs.diffutils}/bin/diff --color=auto -u \
      --label "A (''${short_a})" \
      --label "B (''${short_b})" \
      "$tmp_a" "$tmp_b" || true
  '';
in
  pkgs.symlinkJoin {
    name = "scripts";
    paths = [
      format
      lint
      fix
      diff-versions
    ];
  }

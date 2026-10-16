{pkgs}: let
  ssh-fluffy = pkgs.writeShellScriptBin "ssh-fluffy" ''
    ${pkgs.openssh}/bin/ssh -p $SSH_PORT root@$REMOTE_IP4 "$@"
  '';

  ssh-foggy = pkgs.writeShellScriptBin "ssh-foggy" ''
    ${pkgs.openssh}/bin/ssh -p $SSH_PORT root@$FOGGY_REMOTE_IP4 "$@"
  '';

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

  gen-wgkeys = pkgs.writeShellScriptBin "gen-wgkeys" ''
    set -euo pipefail

    wg="${pkgs.wireguard-tools}/bin/wg"
    sops="${pkgs.sops}/bin/sops"

    # WireGuard keys are base64, which needs no escaping inside a JSON string.
    set_secret() {
      local file="$1" path="$2" value="$3"
      "$sops" set "$file" "$path" "\"$value\""
    }

    foggy_privkey="$("$wg" genkey)"
    fluffy_privkey="$("$wg" genkey)"
    foggy_pubkey="$(printf '%s' "$foggy_privkey" | "$wg" pubkey)"
    fluffy_pubkey="$(printf '%s' "$fluffy_privkey" | "$wg" pubkey)"

    # Each host stores its own private key encrypted, and the peer's public
    # key in the clear (`_unencrypted` suffix), so the peer key can be read
    # without decrypting the file.
    set_secret secrets-foggy.yaml '["wireguard"]["private-key"]' "$foggy_privkey"
    set_secret secrets-foggy.yaml '["wireguard"]["fluffy-pubkey_unencrypted"]' "$fluffy_pubkey"
    set_secret secrets-fluffy.yaml '["wireguard"]["private-key"]' "$fluffy_privkey"
    set_secret secrets-fluffy.yaml '["wireguard"]["foggy-pubkey_unencrypted"]' "$foggy_pubkey"

    echo "Updated wireguard keys in secrets-foggy.yaml and secrets-fluffy.yaml"
  '';
in
  pkgs.symlinkJoin {
    name = "scripts";
    paths = [
      ssh-fluffy
      ssh-foggy
      format
      lint
      fix
      diff-versions
      gen-wgkeys
    ];
  }

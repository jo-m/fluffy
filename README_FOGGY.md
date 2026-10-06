# Foggy 🌫️

Counterpart to Fluffy: Foggy 🌫️ because it's on the ground.
Acer NUC VN1502G N150.

## Installation

### Preparation

The secrets file from fluffy is reused.

1. First, secure boot needs to be configured in UEFI setup so we can enroll our own keys.
   1. A boot medium which is signed with standard keys needs to be present (e.g. Windows, or Ubuntu installer).
      If you end up at the "secure boot failed" prompt, secure boot options are greyed out in setup.
   2. Boot into UEFI setup.
      1. DEL on boot to enter UEFI setup in advanced mode (F2 = user mode), see https://community.acer.com/de/discussion/735337/... maybe?
   3. (Set an admin password in UEFI setup)
   4. Set "Secure Boot: Disabled" and "Secure Boot Mode: Custom"
2. Boot from NixOS live CD (GUI).
3. Connect to WiFi or Ethernet.
4. Open a terminal.
5. Set a password for the nixos user: `passwd`.
6. Show the IP of the machine: `ip addr`.

### Stage 0 (Bootstrap)

Now, we continue from the remote machine which will provision NixOS:

```fish
# Store the IP of the target machine into a variable.
set FOGGY_REMOTE_IP4 10.0.0.159
# Test SSH.
ssh-keygen -R $FOGGY_REMOTE_IP4
ssh nixos@$FOGGY_REMOTE_IP4
exit

# Provision stage0.
# When asked for LUKS passphrase, just hit enter (empty).
NIX_SSHOPTS= SSH_PORT=22 nix run github:nix-community/nixos-anywhere -- \
   --flake .#foggy-stage0 \
   --target-host nixos@$FOGGY_REMOTE_IP4 \
   --generate-hardware-config nixos-generate-config ./foggy/hardware-configuration.nix
# The system will reboot when completed.
```

### Stage 1 (Secure boot)

```fish
set FOGGY_REMOTE_IP4 10.42.0.242 # TODO: Assume LAN IP
# Generate secure boot keys.
ssh -p 4721 root@$FOGGY_REMOTE_IP4 sbctl create-keys
# And install lanzaboote.
nixos-rebuild switch --flake .#foggy-stage1 --target-host root@$FOGGY_REMOTE_IP4
# Verify it worked.
ssh -p 4721 root@$FOGGY_REMOTE_IP4 sbctl verify
#
ssh -p 4721 root@$FOGGY_REMOTE_IP4 sbctl enroll-keys --microsoft
```

Now, we can enroll keys and enable secure (https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html).

# TODO

- [ ] Newest kernel
- [ ] Remove empty keyslot
- [ ] Provision TPM2 keyslot
- [ ] Minimize
- [ ] Systemd-sysusers

# Foggy 🌫️

Counterpart to Fluffy: Foggy 🌫️ because it's on the ground.
Acer NUC VN1502G N150.

https://foggy.local/

## Installation

Note:
I attempted to set up full disk encryption with TPM2 unlock, but the AMI Aptio UEFI on this hardware
does not allow to enroll custom keys ("Key management" option missing), and without secure boot, it's pointless.
Thus, we go without FDE and without secure boot.

1. First, secure boot needs to be disabled in UEFI setup.
   1. A boot medium which is signed with standard keys needs to be present (e.g. Windows, or Ubuntu installer).
      If you end up at the "secure boot failed" prompt, secure boot options are greyed out in setup.
   2. Boot into UEFI setup.
   3. (Set an admin password in UEFI setup)
   4. Set "Secure Boot: Disabled".
2. Boot from NixOS live CD (GUI).
3. Connect to WiFi or Ethernet.
4. Open a terminal.
5. Set a password for the nixos user: `passwd`.
6. Show the IP of the machine: `ip addr`.

### Stage 0 (Bootstrap)

Now, we continue from the remote machine which will provision NixOS:

```fish
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

### Full setup

```fish
ssh -p 4721 root@$FOGGY_REMOTE_IP4
nixos-rebuild switch --flake .#foggy --target-host root@$FOGGY_REMOTE_IP4
```

### Teddycloud

```bash
# Status
systemctl status --user --machine=runner@.host teddycloud.service
systemctl stop --user --machine=runner@.host teddycloud.service
systemctl start --user --machine=runner@.host teddycloud.service
# Logs
sudo -u runner journalctl --user -efu teddycloud
```

# TODO

- [ ] Update prometheus-podman-exporter to v2.0
- [x] Test fwupd
- [ ] Syncthing
- [ ] Immich?
- [x] Monitoring
- [ ] Move fogdb
- [ ] Dedupe lokiPort var
- [x] Teddycloud
- [x] Caddy with subdomains
- [x] mDNS
- [ ] Basic Auth
- [ ] Move content (README etc) from dockerapps repo

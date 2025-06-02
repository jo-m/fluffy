# Secrets

See https://github.com/Mic92/sops-nix.

```bash
# Setup user key.
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y $HOME/.config/sops/age/keys.txt | read AGE_USER_KEY
nix-shell -p yq-go --run "yq -i e '.keys.users.me=\"$AGE_USER_KEY\"' .sops.yaml"

# Edit secrets.
nix-shell -p sops --run "EDITOR='codium --wait' sops secrets.yaml"
```

# Boostrap

1. Click a CX32 server:
   1. Debian 12
   2. Add your ssh key.
   3. Enable public IPv4.
2. (Don't forget to add A and AAAA DNS records, including *.)
3. Provision:

```bash
# Bootstrapping - set up SSH and generate host key.
export REMOTE_IP4=1.1.1.1
export REMOTE_IP6=fe80::1
ssh-keygen -R "[$REMOTE_IP4]:4721"
nix run github:nix-community/nixos-anywhere -- --flake .#fluffy-stage0 --target-host root@$REMOTE_IP4

# Get host key and add to .sops.yaml.
export NIX_SSHOPTS="-p 4721"
ssh $NIX_SSHOPTS root@$REMOTE_IP4 cat /etc/ssh/ssh_host_ed25519_key.pub \
   | nix-shell -p ssh-to-age --run ssh-to-age \
   | read REMOTE_HOST_KEY
nix-shell -p yq-go --run "yq -i e '.keys.hosts.fluffy=\"$REMOTE_HOST_KEY\"' .sops.yaml"
nix-shell -p sops --run "sops updatekeys secrets.yaml"

# Run full installation.
nixos-rebuild switch --flake .#fluffy --target-host root@$REMOTE_IP4

# SSH access.
ssh $NIX_SSHOPTS root@$REMOTE_IP4
```

# TODO

- [x] GC https://ryanseipp.com/post/nixos-server/
- [x] Podman storage, data
- [x] Module args
- [x] Put all proxied apps behind additional safety (Caddy)
- [x] Syncthing devices https://nixos.wiki/wiki/Syncthing
- [ ] Back up data to rsync.net
- [ ] Monitoring
- [ ] All container logs to journald
- [ ] Journald web frontend
- [ ] IPv6
- [ ] More hardening (lynis)
- [x] Ensure SSL is enforced
- [ ] Prefer ipv4 to ipv6 in outgoing connections, to fix hostpoint email ipv6 problem?
- [x] Top level IP blocking or login?
- [ ] Configure Hetzner Firewall

# Notes

- Container data is in `/home/runner/.local/share/containers`
- Data (bind mounts) is in `/data`
- Hetzner cloud-init:

```
/run/cloud-init/instance-data.json
http://169.254.169.254/hetzner/v1/metadata
http://169.254.169.254/hetzner/v1/userdata
/usr/lib/python3/dist-packages/cloudinit/sources/DataSourceHetzner.py
```

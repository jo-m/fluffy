# Boostrap

1. Click a CX12 server:
   1. Debian 12
   2. Add your ssh key.
   3. Enable public IPv4.
2. Provision:

```bash
# Initial
export REMOTE_IP=2.2.2.2
nix run github:nix-community/nixos-anywhere -- --flake .#cloudy --target-host root@$REMOTE_IP

# Later
ssh-keygen -R "[$REMOTE_IP]:4721"
export NIX_SSHOPTS="-p 4721"
nixos-rebuild switch --flake .#cloudy --target-host root@$REMOTE_IP
ssh $NIX_SSHOPTS root@$REMOTE_IP
```

# TODO

- [x] GC https://ryanseipp.com/post/nixos-server/
- [x] Podman storage, data
- [x] Module args
- [ ] Secrets
- [ ] Syncthing https://nixos.wiki/wiki/Syncthing
- [ ] Backups - ZFS? Borg -> Rsync.net? Syncthing? Storage-Box? https://ryanseipp.com/post/nixos-automated-deployment/
- [ ] Monitoring
- [ ] Logging?
- [ ] IPv6
- [ ] More hardening (lynis)
- [x] Ensure SSL is enforced
- [ ] Grep TODO
- [ ] Prefer ipv4 to ipv6 in outgoing connections, to fix hostpoint email ipv6 problem?
- [ ] Top level IP blocking or login?
- [ ] Ensure firewall is enabled

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

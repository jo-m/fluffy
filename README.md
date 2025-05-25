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
ssh-keygen -f /root/.ssh/known_hosts -R $REMOTE_IP
export NIX_SSHOPTS="-p 4721"
nixos-rebuild switch --flake .#cloudy --target-host root@$REMOTE_IP
ssh $NIX_SSHOPTS root@$REMOTE_IP
```

# TODO Hetzner cloud-init

```
/run/cloud-init/instance-data.json
http://169.254.169.254/hetzner/v1/metadata
http://169.254.169.254/hetzner/v1/userdata
/usr/lib/python3/dist-packages/cloudinit/sources/DataSourceHetzner.py
```

# TODO

- [x] GC https://ryanseipp.com/post/nixos-server/
- [ ] ZFS, impermanence, autowipe, ... / https://ryanseipp.com/post/nixos-automated-deployment/
- [ ] Logging?
- [ ] IPv6
- [ ] More hardening (lynis)

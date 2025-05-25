# Boostrap

1. Click a CX12 server:
   1. Debian 12
   2. Add your ssh key.
   3. Enable public IPv4.
2. Provision:

```bash
# Initial
nix run github:nix-community/nixos-anywhere -- --flake .#cloudy --target-host root@2.2.2.2

# Later
ssh-keygen -f /root/.ssh/known_hosts -R 2.2.2.2
export NIX_SSHOPTS="-p 4721"
nixos-rebuild switch --flake .#cloudy --target-host root@2.2.2.2
ssh $NIX_SSHOPTS root@2.2.2.2
```

# TODO Hetzner cloud-init

```
/run/cloud-init/instance-data.json
http://169.254.169.254/hetzner/v1/metadata
http://169.254.169.254/hetzner/v1/userdata
/usr/lib/python3/dist-packages/cloudinit/sources/DataSourceHetzner.py
```

# TODO

- [ ] GC https://ryanseipp.com/post/nixos-server/
- [ ] ZFS, impermanence, autowipe, ... / https://ryanseipp.com/post/nixos-automated-deployment/
- [ ] Logging?
- [ ] IPv6
- [ ] More hardening (lynis)

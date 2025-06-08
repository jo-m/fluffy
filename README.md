# Fluffy Cloud

## Deployment

Prerequisites on the host machine.

- [Nix](https://nixos.org/download/)
- [Direnv](https://direnv.net/)
- [KeePassXC](https://keepassxc.org/)

### Secrets

We use `sops-nix` with `age`, and use KeePassXC as user key store.
See https://github.com/Mic92/sops-nix for more info.

1. Open your KeePassXC database.
2. Go to Tools > Settings, enable browser integration.
3. Set up git-credential-keepassxc: `git-credential-keepassxc configure --group git-credential-keepassxc`
4. Create a KeePassXC entry for the user master key.
   1. With the output of `age-keygen` (pub key as username and private key as password).
   2. Set URL to `age://fluffy-user-key`.
5. Set they key as user key in `.sops.yaml`:

```bash
print-age-pub-key | read AGE_USER_KEY
yq -i e ".keys.users.me=\"$AGE_USER_KEY\"" .sops.yaml

# Edit secrets.
SOPS_AGE_KEY_CMD=print-age-priv-key EDITOR='codium --wait' sops secrets.yaml
```

### Server provisioning

1. Click a CX32 server in the Hetzner Cloud Console:
   1. Debian 12 (although any Linux with sshd should work).
   2. Add your ssh key.
   3. Enable public IPv4.
2. Update the .envrc file with the addresses of the new machine.
3. And run`direnv allow`.
4. Set up DNS:

```
; A Records
@	3600	IN	A	1.1.1.1
; AAAA Records
@	3600	IN	AAAA	fe80::1
; CNAME Records
*	3600	IN	CNAME	example.net.
```

### Bootstrapping

```bash
# Set up SSH and generate host key.
ssh-keygen -R "[$REMOTE_IP4]:4721"
NIX_SSHOPTS="" nix run github:nix-community/nixos-anywhere -- --flake .#fluffy-stage0 --target-host root@$REMOTE_IP4

# Get host key and add to .sops.yaml.
ssh $NIX_SSHOPTS root@$REMOTE_IP4 cat /etc/ssh/ssh_host_ed25519_key.pub \
   | ssh-to-age \
   | read REMOTE_HOST_KEY
yq -i e ".keys.hosts.fluffy=\"$REMOTE_HOST_KEY\"" .sops.yaml
sops updatekeys secrets.yaml
```

### Full installation and updating

```bash
# To apply changes after changing the Nix config, run the same command.
nixos-rebuild switch --flake .#fluffy --impure --target-host root@$REMOTE_IP4
```

### Manual steps after setup

- Readeck user https://readeck.example.net/onboarding
- Syncthing devices and shares https://sync.example.net
- Disable registration https://secrets.example.net/account/instance-settings

### SSH access

```
ssh $NIX_SSHOPTS root@$REMOTE_IP4
```

## Logs

### Containers

> `quadlet-nix` tries to put containers into full management under systemd. This means once a container crashes, it will be fully deleted and debugging mechanisms like `podman ps -a` or `podman logs` will not work.
>
> However, status and logs are still accessible through systemd, namely, `systemctl status <service name>` and `journalctl -u <service name>`, where `<service name>` is container name, `<network name>-network`, `<pod name>-pod`, or similar. These names are the names as appeared in `virtualisation.quadlet.containers.<container name>`, rather than podman container name, in case it's different.
>
> -- https://seiarotg.github.io/quadlet-nix/introduction.html

```bash
# Status
systemctl status --user --machine=runner@.host readeck.service
# Logs
sudo -u runner journalctl --user -efu readeck
```

## Notes

- Container state and images are in `/home/runner/.local/share/containers`
- Data (bind mounts) is in `/data`
- Hetzner cloud-init endpoints and files:

```
/run/cloud-init/instance-data.json
http://169.254.169.254/hetzner/v1/metadata
http://169.254.169.254/hetzner/v1/userdata
/usr/lib/python3/dist-packages/cloudinit/sources/DataSourceHetzner.py
```

## TODO

- [x] GC https://ryanseipp.com/post/nixos-server/
- [x] Podman storage, data
- [x] Module args
- [x] Put all proxied apps behind additional safety (Caddy)
- [x] Syncthing devices https://nixos.wiki/wiki/Syncthing
- [x] IPv6
- [x] Let sops load key from Keepass
- [x] Fix Openobserve collector
- [ ] Backup data to rsync.net
- [ ] Kitchenowl
- [ ] Weather Dashboard
- [ ] Ferrishare config file
- [ ] Dashboard/entrypoint
- [ ] Uptime monitoring https://github.com/louislam/uptime-kuma
- [ ] https://github.com/calcom/cal.com
- [x] Set up openobserve and journald forwarding
- [x] Set up caddy logs to journald instead of /var/log/caddy/access-*.log
- [ ] More hardening (lynis)
- [x] Test if web services work through IPv6
- [x] Ensure SSL is enforced
- [x] Ferrishare
- [x] Top level IP blocking or login?
- [ ] Grep TODO
- [ ] Configure Hetzner Firewall
- [x] https://github.com/HemmeligOrg/Hemmelig.app
- [ ] https://homer-demo.netlify.app/
- [ ] https://github.com/henrygd/beszel
- [ ] https://github.com/Flomp/wanderer
- [ ] https://github.com/dgtlmoon/changedetection.io
- [ ] Monitoring for caddy, fail2ban, sshd, syncthing

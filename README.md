# Fluffy Cloud

## Deployment

Prerequisites on the host machine:

- [Nix](https://nixos.org/download/)
- [Direnv](https://direnv.net/)
- [KeePassXC](https://keepassxc.org/)

### Secrets

[Secrets](secrets.yaml) are managed and deployed with [sops-nix](.sops.yaml).
The `age` master key is pulled from KeePassXC via `git-credential-keepassxc`.
On the host, secrets are decrypted using the SSH host key.

Setup:

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
sops secrets.yaml
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

On the target host, set up only SSH and generate the host key.

```bash
ssh-keygen -R "[$REMOTE_IP4]:4721"
NIX_SSHOPTS="" nix run github:nix-community/nixos-anywhere -- --flake .#fluffy-stage0 --target-host root@$REMOTE_IP4

# Pull the host pub key and encrypt the secrets with it.
ssh $NIX_SSHOPTS root@$REMOTE_IP4 cat /etc/ssh/ssh_host_ed25519_key.pub \
   | ssh-to-age \
   | read REMOTE_HOST_KEY
yq -i e ".keys.hosts.fluffy=\"$REMOTE_HOST_KEY\"" .sops.yaml
sops updatekeys secrets.yaml
```

### Full installation and updating

As we have the secrets available now, we can run the rest of the installation.
To update the installation after changes in this repo are made, the same command can be used.

```bash
nixos-rebuild switch --flake .#fluffy --impure --target-host root@$REMOTE_IP4
```

### Manual steps after initial setup

- Readeck user https://readeck.example.net/onboarding
- Syncthing devices and shares https://sync.example.net
- Disable registration https://secrets.example.net/account/instance-settings

### SSH access

```bash
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
- Data (container bind mounts) is in `/data`
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
- [x] Backup data to rsync.net
- [ ] Kitchenowl
- [ ] Dashboard/entrypoint: https://homer-demo.netlify.app/
- [x] Ferrishare config file
- [x] Set up openobserve and journald forwarding
- [x] Set up caddy logs to journald instead of /var/log/caddy/access-*.log
- [x] Test if web services work through IPv6
- [x] Ensure SSL is enforced
- [x] Ferrishare
- [x] Top level IP blocking or login?
- [ ] Grep TODO
- [x] https://github.com/HemmeligOrg/Hemmelig.app
- [ ] Uptime monitoring https://github.com/louislam/uptime-kuma
- [ ] https://github.com/Flomp/wanderer
- [ ] https://github.com/dgtlmoon/changedetection.io
- [ ] Configure Hetzner Firewall
- [ ] Monitoring for caddy, fail2ban, sshd, syncthing
- [ ] Monitoring for failed backups
- [ ] More hardening (lynis)

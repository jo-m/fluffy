# Fluffy Cloud

Features:

- Encrypted env vars and secrets (sops)
- Automatic Borg backups to rsync.net
- Various apps running as rootless podman containers
- Caddy reverse proxy, automatic TLS, rate limiting
- Dashboard (Homer)
- Webdav server for Joplin sync
- Logging/monitoring (Prometheus, Grafana, Loki)

## Deployment

Prerequisites on the host machine:

- [Nix](https://nixos.org/download/)
- [Direnv](https://direnv.net/)
- [KeePassXC](https://keepassxc.org/)

### Secrets

[Secrets](secrets.yaml) are managed and deployed with [sops-nix](.sops.yaml).
The `age` master key is pulled from KeePassXC via `git-credential-keepassxc`.
On the host, secrets are decrypted using the SSH host key.

Initial setup:

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

1. Click a CPX21 server in the Hetzner Cloud Console:
   1. Debian 12 (although any Linux with `sshd` should work).
   2. Add your SSH key.
   3. Enable public IPv4.
2. Update the `.envrc` file with the IP addresses of the new machine.
3. And run`direnv allow`.
4. Set up DNS:

```
; A Records
@	3600	IN	A	....
; AAAA Records
@	3600	IN	AAAA	:::::::
; CNAME Records
*	3600	IN	CNAME	${REMOTE_TLD}.
```

### Bootstrapping

On the target host, we first set up SSH and pull the new host key, encrypting the secrets with it:

```bash
make bootstrap
make pull-host-key
```

### Full installation and updating

As we have the secrets available now, we can run the rest of the installation.
To update the installation after changes in this repo are made, the same command can be used.

```bash
make push
```

### Manual steps after initial setup

- Readeck user
- Syncthing devices and shares
- Disable registration on Hemmelig
- Kitchenowl setup
- Grafana setup (default: admin:admin)

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

- [x] Configure Hetzner Firewall
- [ ] Monitoring for failed backups (notifications)
- [ ] Monitoring for caddy, fail2ban, sshd, syncthing
- [ ] https://github.com/alextselegidis/easyappointments
- [ ] Fix ferrishare logs

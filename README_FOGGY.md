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
make pull-host-key-foggy
gen-wgkeys
nixos-rebuild switch --flake .#foggy --target-host root@$FOGGY_REMOTE_IP4
```

### Manual steps after initial setup

- Syncthing devices and shares
- Grafana setup (default: admin:admin)

## Teddycloud

```bash
# Status
systemctl status --user --machine=runner@.host teddycloud.service
systemctl stop --user --machine=runner@.host teddycloud.service
systemctl start --user --machine=runner@.host teddycloud.service
# Logs
sudo -u runner journalctl --user -efu teddycloud
```

### Toniebox setup

Pins on Box:
- TxD Orange
- Rxd Red
- GND Brown

Pins on UART adapter:
- TdX Red
- Rxd Orange
- GND Brown

http://localhost:2344/web/tonieboxes/boxsetup/esp32/legacy

```bash
# extract firmware
esptool.py -b 921600 read_flash 0x0 0x800000 certs/tb.esp32.bin

# enter teddycloud
docker exec -it teddycloud /bin/bash
cd /teddycloud

# extract certficates from firmware
mkdir certs/client/esp32
mkdir certs/client/REPLACE_WITH_MAC # REPLACE_WITH_MAC: lo:we:rc:as:ee
teddycloud --esp32-extract certs/tb.esp32.bin --destination certs/client/esp32

# Copy box certificates to teddyCloud
cp certs/client/esp32/CLIENT.DER certs/client/REPLACE_WITH_MAC/client.der
cp certs/client/esp32/PRIVATE.DER certs/client/REPLACE_WITH_MAC/private.der
cp certs/client/esp32/CA.DER certs/client/REPLACE_WITH_MAC/ca.der

# In case of first Toniebox setup for TeddyCloud
cp certs/client/REPLACE_WITH_MAC/client.der certs/client/client.der
cp certs/client/REPLACE_WITH_MAC/private.der certs/client/private.der
cp certs/client/REPLACE_WITH_MAC/ca.der certs/client/ca.der

# Copy certificates to temporary dir
mkdir certs/client/esp32-fakeca
cp certs/client/esp32/CLIENT.DER certs/client/esp32-fakeca/
cp certs/client/esp32/PRIVATE.DER certs/client/esp32-fakeca/
cp certs/server/ca.der certs/client/esp32-fakeca/CA.DER

# Flash CA replacement for TeddyCloud

# copy firmware backup
cp certs/tb.esp32.bin certs/tb.esp32.fakeca.bin

# inject new CA into firmware
teddycloud --esp32-inject certs/tb.esp32.fakeca.bin --source certs/client/esp32-fakeca
# modify IP/hostname (optional)
teddycloud --esp32-hostpatch certs/tb.esp32.fakeca.bin --hostname 10.0.0.13

# flash firmware with new CA
esptool.py -b 921600 write_flash 0x0 tb.esp32.fakeca.bin
```

UART Output:

```
ESP-ROM:esp32s3-20210327
Build:Mar 27 2021
rst:0xf (BROWNOUT_RST),boot:0x8 (SPI_FAST_FLASH_BOOT)
SPIWP:0xee
mode:DIO, clock div:1
load:0x3fcd0108,len:0x118
load:0x403b6000,len:0xb90
load:0x403ba000,len:0x27f4
entry 0x403b61c4
```

## TODO

- [x] Backup
- [x] Basic Auth
- [x] Move content (README etc) from dockerapps repo
- [ ] Immich?

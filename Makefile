.PHONY: bootstrap
bootstrap:
	# Remove old host keys.
	ssh-keygen -R "[$$REMOTE_IP4]:$$SSH_PORT"
	ssh-keygen -R "[$$REMOTE_IP6]:$$SSH_PORT"

	# Set up SSH.
	NIX_SSHOPTS= SSH_PORT=22 nix run github:nix-community/nixos-anywhere -- --flake .#fluffy-stage0 --target-host root@$$REMOTE_IP4

.PHONY: pull-host-key
pull-host-key:
	# Pull the host pub key and encrypt the secrets with it.
	REMOTE_HOST_KEY=$$(ssh $$NIX_SSHOPTS root@$$REMOTE_IP4 cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age) \
		&& yq -i e ".keys.hosts.fluffy=\"$$REMOTE_HOST_KEY\"" .sops.yaml
	sops updatekeys secrets.yaml

.PHONY: push
push:
	nixos-rebuild switch --flake .#fluffy --impure --target-host root@$$REMOTE_IP4

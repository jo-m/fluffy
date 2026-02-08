{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix = {
      url = "github:SEIAROTg/quadlet-nix";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    disko,
    home-manager,
    sops-nix,
    quadlet-nix,
    ...
  }: let
    specialArgs = {
      inherit inputs;
      inherit (self) outputs;
      modules = import ./modules;
      containers = import ./containers;
    };
    hostSystem = "x86_64-linux";
    pkgs = import inputs.nixpkgs {
      system = hostSystem;
    };
  in {
    nixosConfigurations.fluffy-stage0 = nixpkgs.lib.nixosSystem {
      specialArgs = specialArgs;

      modules = [
        ./configuration-stage0.nix
        disko.nixosModules.disko
      ];
    };

    nixosConfigurations.fluffy = nixpkgs.lib.nixosSystem {
      specialArgs = specialArgs;

      modules = [
        ./configuration.nix
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        quadlet-nix.nixosModules.quadlet
        sops-nix.nixosModules.sops
      ];
    };

    formatter.${hostSystem} = nixpkgs.legacyPackages.${hostSystem}.alejandra;

    devShells.${hostSystem}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Scripts
        (import ./scripts.nix {inherit pkgs;})

        # Secrets handling
        age
        git-credential-keepassxc
        sops
        ssh-to-age
        yq-go
        (writeShellScriptBin "print-age-pub-key" ''
          echo 'url=age://fluffy-user-key' | git-credential-keepassxc get | sed -n 's/^username=//p'
        '')
        (writeShellScriptBin "print-age-priv-key" ''
          echo 'url=age://fluffy-user-key' | git-credential-keepassxc get | sed -n 's/^password=//p'
        '')

        # VSCode Caddyfile plugin
        caddy
      ];
    };
  };
}

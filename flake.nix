{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
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

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}

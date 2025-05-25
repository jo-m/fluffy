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

    quadlet-nix = {
      url = "github:SEIAROTg/quadlet-nix";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    disko,
    home-manager,
    quadlet-nix,
    ...
  }: let
    specialArgs = {
      inherit inputs;
      inherit (self) outputs;
      modules = import ./modules;
    };
  in {
    nixosConfigurations.cloudy = let
      args =
        specialArgs
        // {
          hostname = "cloudy";
        };
    in
      nixpkgs.lib.nixosSystem {
        specialArgs = args;

        modules = [
          ./configuration.nix

          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          quadlet-nix.nixosModules.quadlet
        ];
      };

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}

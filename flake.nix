{
  description = "Flake for the Stalwart mail server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        # "x86_64-darwin"
        "aarch64-linux"
        # "aarch64-darwin"
      ];
      # Allows code to execute for all used architectures
      pkgsPerSystem = (lib.genAttrs systems (system: import nixpkgs { inherit system; }));
      forAllSystems = f: (lib.genAttrs systems (system: (f (pkgsPerSystem.${system}) system)));
      # Treefmt has a bunch of long paths that we want to bundle.
      treefmt = forAllSystems (
        pkgs: _system:
        let
          _treefmt = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
        {
          # for `nix fmt`
          formatter = _treefmt.config.build.wrapper;
          # for `nix flake check`
          checks.formatting = _treefmt.config.build.check self;
        }
      );
    in
    {
      formatter = forAllSystems (_pkgs: system: (treefmt.${system}).formatter);
      checks = forAllSystems (_pkgs: system: (treefmt.${system}).checks);
      packages = forAllSystems (pkgs: _system: import ./default.nix { inherit pkgs; });

      nixosModules = {
        stalwart = ./modules/stalwart;
        default = self.nixosModules.stalwart;
      };

      # TODO: Darwin support

      overlays.default = final: _prev: (import ./default.nix { pkgs = final; });
    };
}

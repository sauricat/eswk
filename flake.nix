#!/usr/bin/env bash
/*/
testnix=$(mktemp)
echo "builtins.getFlake (toString $(pwd))" > $testnix
exec nix repl $testnix
*/
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, flake-utils, emacs-overlay, self, ... }: let
    emacsSystems = {
      x64 = "x86_64-linux";
      x86 = "i686-linux";
      arm = "aarch64-linux";
    };
    emacsSystemList = builtins.attrValues emacsSystems;
    #   nixpkgs.lib.lists.intersectLists
    #     nixpkgs.legacyPackages.x86_64-linux.sway.meta.platforms
    #     (builtins.attrNames emacs-overlay.packages);
  in flake-utils.lib.eachSystem emacsSystemList (system: rec {
    packages = {
      eswk = nixpkgs.legacyPackages.${system}.emacsPackages.trivialBuild {
        pname = "eswk";
        ename = "eswk";
        version = "dev";
        src = ./eswk;
      };
    };
    legacyPackages.emacsPackages = packages;
  }) // {
    nixosModules.eswk = { config, pkgs, ... }: let
      cfg = config.programs.eswk;
    in {
      # TODO
    };

    # Run `nixos-rebuild build-vm --no-build-nix --flake path:.#eswk-test-vm-<arch>` to build a test env.
    nixosConfigurations = let
      lib = nixpkgs.lib;
      vm = system: lib.makeOverridable lib.nixosSystem {
        inherit system;
        specialArgs = { };
        modules = [ self.nixosModules.eswk ] ++ lib.singleton ({ pkgs, ... }: let
          emacsTestEnv = pkgs.emacsWithPackagesFromUsePackage {
            config = ./test/init.el;
            package = pkgs.emacsPgtk;
            extraEmacsPackages = epkgs: [ self.packages.${system}.eswk ];
          };
        in {
          imports = [
            (nixpkgs + /nixos/modules/virtualisation/qemu-vm.nix) # Why?
          ];
          nixpkgs.overlays = [ emacs-overlay.overlay ];
          environment.systemPackages = with pkgs; [
            emacsTestEnv
            sway # Don't use `config.packages.sway`.
            foot
          ];
          environment.variables = {
            WLR_NO_HARDWARE_CURSORS = "1";
          };
          users.users.tester = {
            isNormalUser = true;
            password = "1234";
            extraGroups = [ "wheel" ];
          };
          security.sudo = {
            enable = true;
            wheelNeedsPassword = false;
          };
          virtualisation = {
            diskSize = 5120;
            qemu.options = [ "-vga none" "-device virtio-gpu-pci" ]; # sway can't run in a virtualized GPU.
          };
          system.stateVersion = "22.11";
        });
      };
    in lib.mapAttrs' (name: system: lib.nameValuePair ("eswk-test-vm-" + name) (vm system)) emacsSystems;
  };
}

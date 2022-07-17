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
    emacsSystems = builtins.attrNames emacs-overlay.packages;
  in flake-utils.lib.eachSystem emacsSystems (system: rec {
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
  };
}

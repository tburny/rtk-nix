{
  description = "Unofficial Nix packaging for rtk, fetched from upstream GitHub Releases (no from-source build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        rtk = pkgs.callPackage ./package.nix { };
      in
      {
        packages = {
          inherit rtk;
          default = rtk;
        };

        apps.default = {
          type = "app";
          program = "${rtk}/bin/rtk";
        };

        checks.rtk = rtk;
      }
    );
}

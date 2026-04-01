{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # (1) add mkdocs-flake input
    mkdocs-flake.url = "github:applicative-systems/mkdocs-flake";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      # (2) import mkdocs-flake module
      imports = [
        inputs.mkdocs-flake.flakeModules.default
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        { pkgs, ... }:
        {
          packages.default = pkgs.hello;

          # (3) point mkdocs-flake to your mkdocs root folder
          documentation.mkdocs-root = ./docs;

          # (4) Build the docs:
          #     `nix build .#documentation`
          #     Run in watch mode for live-editing-rebuilding:
          #     `nix run .#watch-documentation`
        };
    };
}

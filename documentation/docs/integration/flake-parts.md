
If you already use [flake.parts](https://flake.parts) in your project, then
integrating mkdocs-flake is done with 3 steps:

1. Add `mkdocs-flake` as a flake input
2. Import the flake module
3. Point mkdocs-flake to your documentation root (where the `mkdocs.yaml` is)

A complete example looks like this:

```nix
{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # (1) add mkdocs-flake input
    mkdocs-flake.url = "github:applicative-systems/mkdocs-flake";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    # (2) import mkdocs-flake module
    imports = [
      inputs.mkdocs-flake.flakeModules.default
    ];
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    perSystem = { config, self', inputs', pkgs, system, ... }: {
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
```

## Usage

You can now do sandboxed documentation builds and also live builds:

### Sandboxed build

`mkdocs-flake` creates the `documentation` package for you.
Its output contains all the static files ready for serving them on the internet.

```console
nix build .#documentation
```

### Live Builds

For a nice developer experience that rebuilds the docs while you are editing
them, run:

```console
nix run .#watch-documentation
```

The docs are served on port 8000 on your local machine.

## Template Project

If you want to start with an empty project, run:

```console
nix flake init -t github:applicative-systems/mkdocs-flake
```

This will create an empty project with a `flake.nix` file (like the example
above) and a minimal mkdocs project.

Here, you can run `nix build .#documentation` or `nix run .#watch-documentation`

## Options Reference

<!-- placeholder -->

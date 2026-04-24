{
  flakeSelf,
  pkgs,
  lib,
  config,
  system,
  mkdocs-flake,
  ...
}:

let
  cfg = config.documentation;

  strict = lib.optionalString cfg.strict "--strict";

  yaml = pkgs.formats.yaml { };
  abs_docs_dir = "${flakeSelf.outPath}/${rel_docs_dir}";
  rel_docs_dir = lib.path.removePrefix (
    /. + (builtins.unsafeDiscardStringContext flakeSelf.outPath)
  ) cfg.mkdocs-root;
  settings =
    if cfg.settings != null then
      {
        docs_dir = abs_docs_dir;
      }
      // cfg.settings
    else
      null;
  configFile = if settings != null then yaml.generate "mkdocs.yml" settings else null;
in

{
  options.documentation = {
    mkdocs-root = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "./documentation";
      description = "Path to your mkdocs documentation project with mkdocs.yml. Relative from your flake.nix.";
    };

    mkdocs-package = lib.mkOption {
      type = lib.types.package;
      default = mkdocs-flake.withSystem system (
        { config, ... }: config.packages.mkdocs.override { runtimeInputs = cfg.mkdocs-runtimeInputs; }
      );
      defaultText = "mkdocs-flake.packages.\${system}.mkdocs.override { runtimeInputs = cfg.mkdocs-runtimeInputs; }";
      description = "The mkdocs package to use.";
    };

    mkdocs-preBuildHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "script to run in build directory before calling mkdocs. Can be used to prepare .cache directory with Google fonts so mkdocs does not attempt to download them.";
    };

    mkdocs-runtimeInputs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.plantuml ];
      defaultText = "with pkgs; [ plantuml ]";
      example = ''
        with pkgs; [
          bash
          coreutils
          gnused
        ]
      '';
      description = "Runtime inputs of mkdocs. Allows to make additional tools available when building the documentation.";
    };

    overrideAttrs = lib.mkOption {
      type = lib.types.raw;
      default = _final: _prev: { };
      defaultText = "final: prev: {}";
      example = ''
        final: prev: {
          requiredSystemFeatures = [ "recursive-nix" ];
          NIX_CONFIG = '''
            experimental-features = nix-command recursive-nix
            store = unix:///build/.nix-socket
            substituters = unix:///build/.nix-socket
          ''';
        }
      '';
      description = "Extension (`overrideAttrs`) for the `documentation` derivation.";
    };

    strict = lib.mkEnableOption ''
      Build the documentation with `--strict`

      See also [mkdocs user guide about `--strict`](https://www.mkdocs.org/user-guide/configuration/#strict)

    '';

    settings = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          freeformType = yaml.type;
        }
      );
      default = null;
      description = ''
        Contents of `mkdocs.yml`.

        By setting this to anything other than `null` (the default), `mkdocs.yml` is synthesized from this definition.

        Any `mkdocs.yml` on the filesystem is then ignored.
      '';
    };

    references.enable = lib.mkEnableOption ''
      Automatically generate references from your Nix files

      References document the implementation of various Nix files within a standard filesystem layout of your project. Currently, the following files are documented:

      - ./modules-nixos/*.nix
    '';
  };

  config = lib.mkIf (cfg.mkdocs-root != null) (
    lib.mkMerge [
      {
        # some mkdocs plugins want to create a .cache folder.
        # so we link to the project from the build dir.
        # the hook allows the user to prepopulate font files to help avoid mkdocs
        # connecting to the internet.
        packages.documentation =
          (pkgs.runCommand "mkdocs-flake-documentation" { } ''
            cd ${abs_docs_dir}
            mkdocs_args=(
              --site-dir $out
              ${strict}
            )
            config_file=${lib.optionalString (configFile != null) (toString configFile)}
            if [[ ! -z "$config_file" ]]; then
              mkdocs_args+=(
                --config-file "$config_file"
              )
              if [[ -f mkdocs.yml ]]; then
                2>&1 echo 'warning: local file `mkdocs.yml'"'"' ignored due to `documentation.settings'"'"
              fi
            elif [[ -f mkdocs.yml ]]; then
              mkdocs_args+=(
                --config-file mkdocs.yml
              )
            fi
            eval "${cfg.mkdocs-preBuildHook}"
            ${cfg.mkdocs-package}/bin/mkdocs build "''${mkdocs_args[@]}"
          '').overrideAttrs
            cfg.overrideAttrs;

        apps.watch-documentation = {
          type = "app";
          program = pkgs.writeShellScriptBin "mkdocs-watch" ''
            set -euo pipefail
            cd "${rel_docs_dir}"

            mkdocs_args=(
              ${strict}
            )
            config_file=${lib.optionalString (configFile != null) (toString configFile)}
            if [[ ! -z "$config_file" ]]; then
              mkdocs_args+=(
                --config-file "$config_file"
              )
              if [[ -f mkdocs.yml ]]; then
                2>&1 echo 'warning: local file `mkdocs.yml'"'"' ignored due to `documentation.settings'"'"
              fi
            elif [[ -f mkdocs.yml ]]; then
              mkdocs_args+=(
                --config-file mkdocs.yml
              )
            else
              echo "Can't find mkdocs.yml. Is your flake's `documentation.mkdocs-root` set correctly?"
            fi

            exec ${cfg.mkdocs-package}/bin/mkdocs serve "''${mkdocs_args[@]}"
          '';
          meta.description = "Run mkdocs in watch mode over your documentation folder. Automatically rebuilds your docs on changes.";
        };
      }
      (lib.mkIf cfg.references.enable {
        documentation.settings.plugins = [
          {
            gen-files.scripts = mkdocs-flake.withSystem system (
              { config, ... }:
              [
                "${config.packages.mkdocs-python}/bin/generate-references"
              ]
            );
          }
          {
            literate-nav.nav_file = "SUMMARY.md";
          }
        ];
      })
    ]
  );
}

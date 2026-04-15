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
  configFile =
    if cfg.settings != null then
      yaml.generate "mkdocs.yml" (
        {
          docs_dir = cfg.mkdocs-root;
        }
        // cfg.settings
      )
    else
      null;
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
      default = mkdocs-flake.withSystem system ({ config, ... }: config.packages.mkdocs);
      defaultText = "mkdocs-flake.packages.\${system}.mkdocs";
      description = "The mkdocs package to use.";
    };

    mkdocs-preBuildHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "script to run in build directory before calling mkdocs. Can be used to prepare .cache directory with Google fonts so mkdocs does not attempt to download them.";
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
  };

  config = lib.mkIf (cfg.mkdocs-root != null) (
    lib.mkMerge [
      {
        # some mkdocs plugins want to create a .cache folder.
        # so we link to the project from the build dir.
        # the hook allows the user to prepopulate font files to help avoid mkdocs
        # connecting to the internet.
        packages.documentation = pkgs.runCommand "mkdocs-flake-documentation" { } ''
          cp -as ${cfg.mkdocs-root}/* .
          eval "${cfg.mkdocs-preBuildHook}"
          ${cfg.mkdocs-package}/bin/mkdocs build ${strict} --site-dir $out
        '';

        apps.watch-documentation = {
          type = "app";
          program = pkgs.writeShellScriptBin "mkdocs-watch" ''
            set -euo pipefail
            rel_path=${
              lib.path.removePrefix (/. + (builtins.unsafeDiscardStringContext flakeSelf.outPath)) cfg.mkdocs-root
            }
            cd "$rel_path"

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
    ]
  );
}

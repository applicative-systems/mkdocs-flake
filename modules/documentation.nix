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

  configFileNames = [
    "zensical.toml"
    "mkdocs.yml"
  ];
in

{
  imports = [
    (lib.mkRenamedOptionModule [ "documentation" "mkdocs-root" ] [ "documentation" "root" ])
    (lib.mkRenamedOptionModule [ "documentation" "mkdocs-package" ] [ "documentation" "package" ])
    (lib.mkRenamedOptionModule
      [ "documentation" "mkdocs-preBuildHook" ]
      [ "documentation" "preBuildHook" ]
    )
  ];

  options.documentation = {
    root = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "./documentation";
      description = ''
        Path to your documentation project containing a `zensical.toml` or
        `mkdocs.yml`. Relative from your flake.nix.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = mkdocs-flake.withSystem system ({ config, ... }: config.packages.zensical);
      defaultText = "mkdocs-flake.packages.\${system}.zensical";
      description = "The zensical package to use.";
    };

    preBuildHook = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Script to run in the build directory before calling zensical.
        Can be used to prepare files that would otherwise be downloaded.
      '';
    };

    site-dir = lib.mkOption {
      type = lib.types.str;
      default = "site";
      description = ''
        The output directory of the build, relative to `documentation.root`.
        Must match the `site_dir` setting of your configuration file.
      '';
    };

    strict = lib.mkEnableOption ''
      Build the documentation with `--strict`, which aborts the build on warnings
    '';
  };

  config = lib.mkIf (cfg.root != null) {
    # zensical writes its output and a .cache folder into the project
    # directory, so we build in a writable copy of the project.
    packages.documentation = pkgs.runCommand "mkdocs-flake-documentation" { } ''
      cp -r --no-preserve=mode ${cfg.root} docs-root
      cd docs-root
      eval "${cfg.preBuildHook}"
      ${cfg.package}/bin/zensical build ${strict}
      mv ${lib.escapeShellArg cfg.site-dir} $out
    '';

    apps.watch-documentation = {
      type = "app";
      program = pkgs.writeShellScriptBin "zensical-watch" ''
        set -euo pipefail
        has_config() {
          for f in ${lib.escapeShellArgs configFileNames}; do
            test -f "$1/$f" && return 0
          done
          return 1
        }
        if ! has_config .; then
          rel_path=${
            lib.path.removePrefix (/. + (builtins.unsafeDiscardStringContext flakeSelf.outPath)) cfg.root
          }
          if has_config "$rel_path"; then
            echo "Your documentation is in $rel_path. Switching into that folder."
            cd "$rel_path"
          else
            echo "Can't find zensical.toml or mkdocs.yml. Is your flake's \`documentation.root\` set correctly?"
            exit 1
          fi
        fi

        exec ${cfg.package}/bin/zensical serve "$@"
      '';
      meta.description = "Run zensical in watch mode over your documentation folder. Automatically rebuilds your docs on changes.";
    };
  };
}

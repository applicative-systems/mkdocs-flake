{ flakeSelf, pkgs, lib, config, system, mkdocs-flake, ... }:

let
  cfg = config.documentation;

  strict = lib.optionalString cfg.strict "--strict";
  docsRoot = flakeSelf + "/" + cfg.mkdocs-root;
in

{
  options.documentation = {
    mkdocs-root = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "./documentation";
      description = "Path to your mkdocs documentation project with mkdocs.yml. Relative from your flake.nix.";
    };

    mkdocs-package = lib.mkOption {
      type = lib.types.package;
      default = mkdocs-flake.withSystem system ({ config, ... }: config.packages.mkdocs);
      defaultText = ''mkdocs-flake.packages.''${system}.mkdocs'';
      description = "The mkdocs package to use.";
    };

    strict = lib.mkEnableOption ''
      Build the documentation with `--strict`

      See also [mkdocs user guide about `--strict`](https://www.mkdocs.org/user-guide/configuration/#strict)

    '';
  };

  config = lib.mkIf (cfg.mkdocs-root != null) {
    packages.documentation = pkgs.runCommand "mkdocs-flake-documentation" {} ''
      cd ${docsRoot}
      ${cfg.mkdocs-package}/bin/mkdocs build ${strict} --site-dir $out
    '';

    apps.watch-documentation = {
      type = "app";
      program = pkgs.writeShellScriptBin "mkdocs-watch" ''
        set -euo pipefail
        if ! test -f mkdocs.yml; then
          if test -f "${cfg.mkdocs-root}/mkdocs.yml"; then
            echo "Your documentation is in ${cfg.mkdocs-root}. Switching into that folder."
            cd "${cfg.mkdocs-root}"
          else
            echo "Can't find mkdocs.yml. Is your flake's `documentation.mkdocs-root` set correctly?"
          fi
        fi

        ${cfg.mkdocs-package}/bin/mkdocs serve ${strict}
      '';
    };
  };
}

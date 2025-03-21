{
  description = "Mkdocs Distribution Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, flake-parts-lib, ... }:
    let
      inherit (flake-parts-lib) importApply;
      flakeModule = importApply ./flake-module.nix { inherit withSystem; };
    in
    {
      imports = [
        flakeModule
      ];

      flake = {
        inherit flakeModule;
        flakeModules.default = flakeModule;

        templates = {
          default = {
            path = ./template;
            description = ''
              A minimal flake using mkdocs-flake.
            '';
          };
        };
      };


      systems = [
        "aarch64-linux"
        "x86_64-linux"

        "aarch64-darwin"
        # "x86_64-darwin" has some python build fails in ps-utils and watchdog
      ];
      perSystem = { config, self', inputs', pkgs, lib, system, ... }:
        let
          python = pkgs.python3;
        in {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              (import ./overlay.nix)
              inputs.poetry2nix.overlays.default
            ];
          };

          devShells.default = pkgs.mkShell {
            nativeBuildInputs = [
              config.packages.default
              pkgs.poetry
              python.pkgs.plantuml-markdown
              pkgs.fontconfig
              pkgs.dejavu_fonts
            ];
          };

          packages = {
            default = config.packages.mkdocs;

            mkdocs-python = pkgs.poetry2nix.mkPoetryEnv {
              inherit python;
              projectDir = ./mkdocs;
              overrides = pkgs.poetry2nix.overrides.withDefaults
                (import ./python-overrides.nix);
            };

            mkdocs = pkgs.runCommand "mkdocs" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
              makeWrapper ${config.packages.mkdocs-python}/bin/mkdocs $out/bin/mkdocs \
                --set PATH ${lib.makeBinPath [
                  pkgs.plantuml
                ]}
            '';


            flake-parts-options =
              let
                minimalOptions = { lib, ... }:
                  let
                    fakeOption = lib.mkOption { internal = true; };
                  in
                    {
                    options = {
                      apps = fakeOption;
                      packages = fakeOption;
                    };
                };
                eval = pkgs.lib.evalModules {
                  modules = [
                    minimalOptions
                    ./modules/documentation.nix
                  ];
                };
                optionsDoc = pkgs.nixosOptionsDoc {
                  options = {
                    inherit (eval.options) documentation;
                  };
                  documentType = "none";
                };
              in
                optionsDoc.optionsCommonMark;

            documentation =
              let
                mkdocs-root = pkgs.runCommand "documentation" {} ''
                  cp -r ${./documentation} $out
                  substituteInPlace $out/docs/integration/flake-parts.md \
                    --replace "<!-- placeholder -->" "$(cat ${config.packages.flake-parts-options})"
                '';
              in
                pkgs.runCommand "mkdocs-flake-documentation" {} ''
                  cd ${mkdocs-root}
                  ${config.packages.mkdocs}/bin/mkdocs build --strict --site-dir $out
                  sed -i 's|/nix/store/[^/]\+/||g' $out/integration/flake-parts.html
                '';
          } // lib.optionalAttrs pkgs.stdenv.isLinux {

            docker = pkgs.dockerTools.buildImage {
              name = "applicativesystems/mkdocs";
              tag = "latest";

              copyToRoot = pkgs.buildEnv {
                name = "image-root";
                paths = [
                  config.packages.mkdocs
                ];
                pathsToLink = [ "/bin" ];
              };

              config = {
                Cmd = [ "/bin/mkdocs" "serve" ];
                WorkingDir = "/data";
                Volumes = { "/data" = { }; };
              };

              runAsRoot = ''
                #!${pkgs.runtimeShell}
                ${pkgs.dockerTools.shadowSetup}
              '';
            };
          };

          apps = {
            default = {
              type = "app";
              program = pkgs.writeScriptBin "mkdocs-watch" ''
                ${config.packages.mkdocs}/bin/mkdocs serve
              '';
            };
          };

          checks = config.packages // {
            devShell = config.packages.default;
          };
        };
    });

  nixConfig = {
    extra-substituters = [
      "https://appsys.cachix.org"
    ];
    extra-trusted-public-keys = [
      "appsys.cachix.org-1:VoZof6Mp3Aqlj3tQ21wFdxW0lhHTzAu/5q04LYUtXM8="
    ];
  };
}

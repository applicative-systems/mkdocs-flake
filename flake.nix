{
  description = "Zensical Distribution Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, flake-parts-lib, ... }:
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
                A minimal flake using mkdocs-flake with Zensical.
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
        perSystem =
          {
            config,
            pkgs,
            lib,
            system,
            ...
          }:
          let
            workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
              workspaceRoot = ./mkdocs;
            };
            overlay = workspace.mkPyprojectOverlay {
              sourcePreference = "wheel";
            };

            python = pkgs.python3;

            vendor = pkgs.callPackage ./vendor.nix { };

            pythonSet =
              (pkgs.callPackage inputs.pyproject-nix.build.packages {
                inherit python;
              }).overrideScope
                (
                  lib.composeManyExtensions [
                    inputs.pyproject-build-systems.overlays.default
                    overlay
                    (import ./python-fix-overlay.nix)
                    (import ./zensical-vendor-overlay.nix { inherit vendor; })
                  ]
                );

            treefmt = pkgs.treefmt.withConfig {
              settings = {
                tree-root-file = "flake.nix";
                on-unmatched = "info";
                formatter = {
                  nixfmt = {
                    command = lib.getExe pkgs.nixfmt;
                    includes = [ "*.nix" ];
                  };
                  statix = {
                    command = lib.getExe pkgs.statix;
                    options = [ "fix" ];
                    no-positional-arg-support = true;
                    includes = [ "*.nix" ];
                  };
                  deadnix = {
                    command = lib.getExe pkgs.deadnix;
                    options = [ "--edit" ];
                    includes = [ "*.nix" ];
                  };
                  prettier = {
                    command = lib.getExe pkgs.prettier;
                    options = [ "--write" ];
                    includes = [
                      "*.md"
                      "*.yaml"
                      "*.yml"
                    ];
                  };
                  shfmt = {
                    command = lib.getExe pkgs.shfmt;
                    options = [
                      "-w"
                      "-i"
                      "2"
                      "-s"
                    ];
                    includes = [
                      "*.sh"
                      "*.bash"
                      "*.envrc"
                    ];
                  };
                };
              };
            };
          in
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                (import ./overlay.nix)
                inputs.poetry2nix.overlays.default
              ];
            };

            devShells.default = pkgs.mkShell {
              packages = [
                python.pkgs.plantuml-markdown
                pkgs.fontconfig
                pkgs.dejavu_fonts
                pkgs.uv
                inputs.self.formatter.${system}
              ];
            };

            documentation.root = ./documentation;

            formatter = treefmt;

            packages = {
              default = config.packages.zensical;

              zensical-python = pythonSet.mkVirtualEnv "zensical-env" workspace.deps.default;
              zensical = pkgs.runCommand "zensical" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
                makeWrapper ${config.packages.zensical-python}/bin/zensical $out/bin/zensical \
                  --set PATH ${
                    lib.makeBinPath [
                      pkgs.plantuml
                    ]
                  }
              '';

              flake-parts-options =
                let
                  minimalOptions =
                    { lib, ... }:
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

              documentation-pages = pkgs.runCommand "mkdocs-flake-documentation" { } ''
                cp -r --no-preserve=mode ${./documentation} docs-root
                cd docs-root
                substituteInPlace docs/integration/flake-parts.md \
                  --replace-fail "<!-- placeholder -->" "$(cat ${config.packages.flake-parts-options})"
                ${config.packages.zensical}/bin/zensical build --strict
                mv site $out
                sed -i 's|/nix/store/[^/]\+/||g' $out/integration/flake-parts.html
              '';
            }
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {

              docker = pkgs.dockerTools.buildImage {
                name = "applicativesystems/zensical";
                tag = "latest";

                copyToRoot = pkgs.buildEnv {
                  name = "image-root";
                  paths = [
                    config.packages.zensical
                  ];
                  pathsToLink = [ "/bin" ];
                };

                config = {
                  Cmd = [
                    "/bin/zensical"
                    "serve"
                    "--dev-addr"
                    "0.0.0.0:8000"
                  ];
                  WorkingDir = "/data";
                  Volumes = {
                    "/data" = { };
                  };
                };

                runAsRoot = ''
                  #!${pkgs.runtimeShell}
                  ${pkgs.dockerTools.shadowSetup}
                '';
              };
            };

            checks = config.packages // {
              devShell = config.packages.default;
              formatting = treefmt.check inputs.self;
            };
          };
      }
    );

  nixConfig = {
    extra-substituters = [
      "https://appsys.cachix.org"
    ];
    extra-trusted-public-keys = [
      "appsys.cachix.org-1:VoZof6Mp3Aqlj3tQ21wFdxW0lhHTzAu/5q04LYUtXM8="
    ];
  };
}

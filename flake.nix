{
  description = "Mkdocs Distribution Flake";

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

    treefmt-nix.url = "github:numtide/treefmt-nix";
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
              path = ./template/default;
              description = ''
                A minimal flake using mkdocs-flake.
              '';
            };
            references = {
              path = ./template/references;
              description = ''
                TODO
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

            pythonSet =
              (pkgs.callPackage inputs.pyproject-nix.build.packages {
                inherit python;
              }).overrideScope
                (
                  lib.composeManyExtensions [
                    inputs.pyproject-build-systems.overlays.default
                    overlay
                    (import ./uv-overrides.nix)
                    (import ./python-fix-overlay.nix)
                  ]
                );

            treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
              projectRootFile = "flake.nix";
              programs = {
                deadnix.enable = true;
                nixfmt.enable = true;
                prettier.enable = true;
                shfmt.enable = true;
                statix.enable = true;
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
              nativeBuildInputs = [
                python.pkgs.plantuml-markdown
                pkgs.fontconfig
                pkgs.dejavu_fonts
                pkgs.uv
              ];
            };

            documentation.mkdocs-root = ./documentation;

            formatter = treefmtEval.config.build.wrapper;

            packages = {
              default = config.packages.mkdocs;

              mkdocs-python = pythonSet.mkVirtualEnv "mkdocs-env" workspace.deps.default;
              mkdocs = pkgs.runCommand "mkdocs" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
                makeWrapper ${config.packages.mkdocs-python}/bin/properdocs $out/bin/mkdocs \
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
                      config._module.args.pkgs = {
                        inherit (pkgs) formats;
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

              documentation-pages =
                let
                  mkdocs-root = pkgs.runCommand "documentation" { } ''
                    cp -r ${./documentation} $out
                    substituteInPlace $out/docs/integration/flake-parts.md \
                      --replace "<!-- placeholder -->" "$(cat ${config.packages.flake-parts-options})"
                  '';
                in
                pkgs.runCommand "mkdocs-flake-documentation" { } ''
                  cd ${mkdocs-root}
                  ${config.packages.mkdocs}/bin/mkdocs build --strict --site-dir $out
                  sed -i 's|/nix/store/[^/]\+/||g' $out/integration/flake-parts.html
                '';
            }
            // lib.optionalAttrs pkgs.stdenv.isLinux {

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
                  Cmd = [
                    "/bin/mkdocs"
                    "serve"
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
              formatting = treefmtEval.config.build.check inputs.self;
              references =
                let
                  inherit ((builtins.getFlake "path:${toString ./.}?dir=template/references").packages.x86_64-linux)
                    documentation
                    ;
                in
                pkgs.runCommand "references" { } ''
                  cd ${documentation}

                  expectedOutput='NixOS module: foo
                  I am a NixOS module.
                  Feature 1
                  I am feature 1 of NixOS module foo.
                  (lib.mkIf (config ? "something") {
                    foo = "bar";
                  })

                  Feature 2
                  I am feature 2 of NixOS module foo.
                  {
                    baz = "bang";
                    quux = lib.mkDefault null; # this should not render
                  }'
                  output=$(
                    <${documentation}/references/modules-nixos/foo/index.html \
                    ${lib.getExe pkgs.htmlq} --text --ignore-whitespace 'div[role=main]'
                  )
                  ${lib.getExe' pkgs.diffutils "diff"} --unified \
                    <(echo "$expectedOutput") \
                    <(echo "$output")

                  touch $out
                '';
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

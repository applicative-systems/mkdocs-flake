final: prev:
let
  inherit (final) resolveBuildSystem;
  inherit (builtins) mapAttrs;

  buildSystemOverrides = {
    mkdocs-exclude.setuptools = [];
    mkdocs-get-deps.hatchling = [];
    mkdocs-glightbox.setuptools = [];
    mkdocs-drawio-exporter.poetry-core = [];
    mkdocs-redirects.hatchling = [];
    plantuml-markdown.setuptools = [];
  };

in
mapAttrs (
  name: spec:
  prev.${name}.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ resolveBuildSystem spec;
  })
) buildSystemOverrides

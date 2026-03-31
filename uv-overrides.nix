final: prev:
let
  inherit (final) resolveBuildSystem;
  inherit (builtins) mapAttrs;

  buildSystemOverrides = {
    mkdocs-exclude.setuptools = [ ];
  };

in
mapAttrs (
  name: spec:
  prev.${name}.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ resolveBuildSystem spec;
  })
) buildSystemOverrides

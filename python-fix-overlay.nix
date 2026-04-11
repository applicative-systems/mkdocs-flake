final: prev: {
  cairocffi =
    (prev.cairocffi.override {
      sourcePreference = "sdist";
    }).overrideAttrs
      (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [
          (final.resolveBuildSystem {
            flit-core = [ ];
          })
        ];

        patches = (old.patches or [ ]) ++ [
          (builtins.head final.pkgs.python3Packages.cairocffi.patches)
        ];
      });
}

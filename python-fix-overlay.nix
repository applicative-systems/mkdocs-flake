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

        patches = (old.patches or [ ]) ++ final.pkgs.python3Packages.cairocffi.patches;
      });

  mkdocs-material = prev.mkdocs-material.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp -r ${final.pkgs.callPackage ./vendored-js { }} \
        $out/${final.python.sitePackages}/material/templates/assets/vendor
    '';
  });
}

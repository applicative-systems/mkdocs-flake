final: prev: {
  cairocffi = prev.cairocffi.overrideAttrs (_old: {
    postInstall = ''
      (
        cd $out/lib/python3*/site-packages/cairocffi
        patch="${builtins.head final.pkgs.python3Packages.cairocffi.patches}"
        patch -p2 < "$patch"
      )
    '';
  });
}

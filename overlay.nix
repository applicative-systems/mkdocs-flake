final: prev: {

  plantuml =
    let
      jre = final.runCommand "headless-jre" { nativeBuildInputs = [ final.makeWrapper ]; } ''
        mkdir -p $out/bin
        makeWrapper ${final.jre}/bin/java $out/bin/java \
          --add-flags "-Djava.awt.headless=true"
      '';

    in
    prev.plantuml.override { inherit jre; };

  pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
    (_pFinal: _pPrev: {
    })
  ];

  python311 =
    let
      self = prev.python311.override {
        inherit self;
        packageOverrides = prev.lib.composeManyExtensions final.pythonPackagesOverlays;
      };
    in
    self;
}

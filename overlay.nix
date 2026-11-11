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
}

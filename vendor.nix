# Third-party browser assets that the zensical theme would otherwise load from
# CDNs (unpkg.com, cdn.jsdelivr.net) at runtime. We fetch them at build time
# with fixed hashes and ship them inside the theme, so generated sites don't
# contact foreign domains.
{
  runCommand,
  fetchurl,
  fetchzip,
}:

let
  npmFile =
    {
      pname,
      version,
      path,
      hash,
    }:
    fetchurl {
      url = "https://cdn.jsdelivr.net/npm/${pname}@${version}/${path}";
      inherit hash;
    };

  mermaid = npmFile {
    pname = "mermaid";
    version = "12.3.0";
    path = "dist/mermaid.min.js";
    hash = "sha256-M234A9h6OLcKAec25mbI92AdLOQvXkfI+v5dchB0uaM=";
  };

  glightbox-js = npmFile {
    pname = "glightbox";
    version = "3.3.1";
    path = "dist/js/glightbox.min.js";
    hash = "sha256-xnxZzfmAeTsCFsnenG6/aIQYg4girx5QsJQ546oon/M=";
  };

  glightbox-css = npmFile {
    pname = "glightbox";
    version = "3.3.1";
    path = "dist/css/glightbox.min.css";
    hash = "sha256-bT9i1NF5afnHDpQ4z2cQBHJQGehoEj8uvClaAG+NXS0=";
  };

  iframe-worker-shim = npmFile {
    pname = "iframe-worker";
    version = "1.0.4";
    path = "shim/index.js";
    hash = "sha256-6OQS28/qm34xtf+iiNe2A1kV5xTFQvQXagzb4mL8lgk=";
  };

  resize-observer-polyfill = npmFile {
    pname = "resize-observer-polyfill";
    version = "1.5.1";
    path = "dist/ResizeObserver.js";
    hash = "sha256-IpC1xg4M3GKFH7aHgAI3JzrFN5dZWxsTOGDE8Tht43g=";
  };

  mathjax = fetchzip {
    url = "https://registry.npmjs.org/mathjax/-/mathjax-3.2.2.tgz";
    hash = "sha256-KFtCOTH1/4xgDOz/Xr0F8pteCtRg0TmAsjn9Wzv0M/M=";
  };

  # Only the SVGs. pymdownx.emoji's twemoji index is generated from this release.
  twemoji = fetchzip {
    url = "https://github.com/jdecked/twemoji/archive/refs/tags/v16.0.1.tar.gz";
    hash = "sha256-VVPoHMqH7xSmnRUH8tkajqP+1POPWHxkABahi3V2ugc=";
    postFetch = ''
      mv $out/assets/svg $TMPDIR/svg
      rm -rf $out
      mv $TMPDIR/svg $out
    '';
  };
in
{
  inherit twemoji;

  # Directory that gets copied into the theme's `assets/vendor` folder
  assets = runCommand "zensical-vendor-assets" { } ''
    mkdir -p $out/glightbox $out/mathjax
    cp ${mermaid} $out/mermaid.min.js
    cp ${glightbox-js} $out/glightbox/glightbox.min.js
    cp ${glightbox-css} $out/glightbox/glightbox.min.css
    cp ${iframe-worker-shim} $out/iframe-worker-shim.js
    cp ${resize-observer-polyfill} $out/resize-observer-polyfill.js

    # MathJax: the combined TeX/MathML -> HTML component plus everything it
    # lazy-loads (TeX extensions, fonts, accessibility, menu, speech).
    cp ${mathjax}/es5/tex-mml-chtml.js $out/mathjax/
    for d in a11y adaptors input output/chtml sre ui; do
      mkdir -p $out/mathjax/$(dirname $d)
      cp -r ${mathjax}/es5/$d $out/mathjax/$d
    done

    cp ${./vendor/mathjax-loader.js} $out/mathjax-loader.js
  '';
}

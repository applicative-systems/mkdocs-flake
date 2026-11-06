# Third-party JavaScript served from the documentation site itself instead of
# CDNs. Installed into mkdocs-material's theme directory (see
# python-fix-overlay.nix), so every site built with this distribution gets it
# at `assets/vendor/`.
{ runCommand, fetchzip }:

let
  npm =
    name: version: hash:
    fetchzip {
      url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
      inherit hash;
    };

  mathjax = npm "mathjax" "3.2.2" "sha256-KFtCOTH1/4xgDOz/Xr0F8pteCtRg0TmAsjn9Wzv0M/M=";
  mermaid = npm "mermaid" "11.17.2" "sha256-gfyAxEe0OkY8r9ngaWBEQxSn2pdApXArxI/uyvZXWTw=";
  iframe-worker = npm "iframe-worker" "1.0.4" "sha256-NQnHZ3jkDJCN2ykuf2vfTq3MRcnOuL9Vuj4r1f6unCI=";
in

runCommand "mkdocs-vendored-js" { } ''
  # tex-mml-chtml.js loads its fonts relative to its own location
  mkdir -p $out/mathjax/output/chtml/fonts
  cp ${./mathjax-config.js} $out/mathjax/config.js
  cp ${mathjax}/es5/tex-mml-chtml.js ${mathjax}/LICENSE $out/mathjax/
  cp -r ${mathjax}/es5/output/chtml/fonts/woff-v2 $out/mathjax/output/chtml/fonts/

  mkdir -p $out/mermaid
  cp ${mermaid}/dist/mermaid.min.js ${mermaid}/LICENSE $out/mermaid/

  mkdir -p $out/iframe-worker
  cp ${iframe-worker}/shim/index.js $out/iframe-worker/shim.js
  cp ${iframe-worker}/LICENSE $out/iframe-worker/
''

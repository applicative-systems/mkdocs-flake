// Loads the vendored MathJax on demand, i.e. only on pages that contain math
// rendered by `pymdownx.arithmatex` (with `generic: true`), and re-typesets
// after instant navigation. Added to every page by mkdocs-flake.
(function () {
  var base = new URL(".", document.currentScript.src).href;
  var loading = null;

  // Back off if the site brings its own MathJax, e.g. via `extra_javascript`
  function userProvidesMathJax() {
    return Array.prototype.some.call(document.scripts, function (script) {
      return /mathjax/i.test(script.src) && script.src.indexOf(base) !== 0;
    });
  }

  function load() {
    if (!loading) {
      window.MathJax = window.MathJax || {
        tex: {
          inlineMath: [["\\(", "\\)"]],
          displayMath: [["\\[", "\\]"]],
          processEscapes: true,
          processEnvironments: true,
        },
        options: {
          ignoreHtmlClass: ".*|",
          processHtmlClass: "arithmatex",
        },
        startup: { typeset: false },
      };
      loading = new Promise(function (resolve, reject) {
        var script = document.createElement("script");
        script.src = base + "mathjax/tex-mml-chtml.js";
        script.async = true;
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
      }).then(function () {
        return MathJax.startup.promise;
      });
    }
    return loading;
  }

  document$.subscribe(function () {
    if (!document.querySelector(".arithmatex") || userProvidesMathJax()) return;
    load().then(function () {
      MathJax.startup.output.clearCache();
      MathJax.typesetClear();
      MathJax.texReset();
      return MathJax.typesetPromise();
    });
  });
})();

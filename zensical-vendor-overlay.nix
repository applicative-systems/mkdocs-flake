# Patches zensical and its theme (zensical-ui) so that generated sites don't
# load assets from CDNs, but from the vendored copies in ./vendor.nix.
{ vendor }:
final: prev:
let
  inherit (final.pkgs) lib;
  sitePackages = "$out/${final.python.sitePackages}";

  # JS expression resolving a file in the theme's `assets/vendor` folder
  # relative to the theme's bundle script, so it works on every page depth.
  vendorUrl =
    file:
    ''new URL("../vendor/${file}",document.querySelector('script[src*="javascripts/bundle."]').src).href'';

  bundleReplacements = {
    "https://unpkg.com/mermaid@12/dist/mermaid.min.js" = "mermaid.min.js";
    "https://unpkg.com/glightbox@3/dist/js/glightbox.min.js" = "glightbox/glightbox.min.js";
    "https://unpkg.com/glightbox@3/dist/css/glightbox.min.css" = "glightbox/glightbox.min.css";
    "https://unpkg.com/resize-observer-polyfill" = "resize-observer-polyfill.js";
  };
in
{
  zensical-ui = prev.zensical-ui.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      templates=${sitePackages}/zensical_ui/templates
      cp -r ${vendor.assets} $templates/assets/vendor
      chmod -R u+w $templates/assets/vendor

      bundle=$(echo $templates/assets/javascripts/bundle.*.min.js)
      substituteInPlace "$bundle" ${
        lib.concatStringsSep " " (
          lib.mapAttrsToList (
            url: file:
            "--replace-fail ${lib.escapeShellArg ''"${url}"''} ${lib.escapeShellArg (vendorUrl file)}"
          ) bundleReplacements
        )
      }
      if grep -qE 'https://(unpkg\.com|cdn\.jsdelivr\.net)/(mermaid|glightbox|resize-observer)' "$bundle"; then
        echo "zensical-ui bundle still references CDN assets that should be vendored" >&2
        exit 1
      fi

      # Load MathJax on demand from the vendored copy
      sed -i "/<script src=.*assets\/javascripts\/bundle\.[0-9a-f]*\.min\.js/a\\
      <script src=\"{{ 'assets/vendor/mathjax-loader.js' | url }}\"></script>" \
        $templates/base.html
      grep -q mathjax-loader.js $templates/base.html
    '';
  });

  zensical = prev.zensical.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      # The offline plugin adds the iframe-worker shim as polyfill
      substituteInPlace ${sitePackages}/zensical/config.py \
        --replace-fail '"https://unpkg.com/iframe-worker/shim"' '"assets/vendor/iframe-worker-shim.js"'

      # Inline twemoji SVGs instead of referencing them on cdn.jsdelivr.net
      substituteInPlace ${sitePackages}/zensical/extensions/emoji.py \
        --replace-fail '    # Delegate to `pymdownx.emoji` extension' '    # Inline vendored twemoji SVG (patched in by mkdocs-flake)
          svg = os.path.join("${vendor.twemoji}", f"{uc}.svg")
          if index == "twemoji" and "image_path" not in options and os.path.exists(svg):
              el = Element("span", {"class": options.get("classes", index), "title": title or alt, "role": "img", "aria-label": alt})
              el.text = md.htmlStash.store(_load(svg))
              return el

          # Delegate to `pymdownx.emoji` extension'
    '';
  });
}

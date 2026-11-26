!!! note

    We assume that you have [nix](https://nixos.org) installed.

To simply run the pre-bundled version of this Zensical bundle on your own
documentation, you can run it in watch mode via `nix run` even without cloning
the repository:

```console
nix run github:applicative-systems/mkdocs-flake -- serve
```

Result:

```console
$ nix run github:applicative-systems/mkdocs-flake -- serve
Serving /path/to/your/docs/site on http://localhost:8000
Build started
No issues found
Build finished in 14.62s
```

This process watches changes and rebuilds the docs if necessary.
Keep it open while you are editing your docs.

### Command line reference

Zensical knows the commands `new`, `build`, and `serve`.
Run `nix run github:applicative-systems/mkdocs-flake -- --help` for details.

To build your documentation instead of serving it, run:

```console
nix run github:applicative-systems/mkdocs-flake -- build --strict
```

The `--strict` is optional but is helpful to avoid usual mistakes.

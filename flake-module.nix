mkdocs-flake:
{ self, flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      imports = [
        ./modules/documentation.nix
      ];

      config = {
        _module.args.mkdocs-flake = mkdocs-flake;
        _module.args.flakeSelf = self;
      };
    }
  );

  _file = __curPos.file;
}

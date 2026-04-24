/*
  # NixOS module: foo

  I am a NixOS module.
*/
{ config, lib, ... }:
{
  options = { };
  config = lib.mkMerge [
    /*
      ## Feature 1

      I am feature 1 of NixOS module foo.
    */
    (lib.mkIf (config ? "something") {
      foo = "bar";
    })
    /*
      ## Feature 2

      I am feature 2 of NixOS module foo.
    */
    {
      baz = "bang";
      quux = lib.mkDefault null; # this should not render
    }
  ];
}

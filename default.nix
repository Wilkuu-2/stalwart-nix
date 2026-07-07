{
  pkgs ? import <nixpkgs> { },
}:
{
  stalwart16 = pkgs.stalwart_0_16;
  stalwart16-cli = pkgs.callPackage ./packages/stalwart-cli/package.nix { };
}

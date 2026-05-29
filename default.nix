{
  pkgs ? import <nixpkgs> { },
}:
{
  stalwart16 = pkgs.callPackage ./packages/stalwart/package.nix { };
  stalwart16-cli = pkgs.callPackage ./packages/stalwart-cli/package.nix { };
}

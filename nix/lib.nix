# ronix — RON ↔ Nix interop library
#
# Provides toRON, fromRON, importRON, mkRON, and isRONType.
# Originally based on cosmic-manager's ron.nix, adapted for standalone use.
{lib, ...}: let
  fromRON = import ./fromRON.nix {inherit lib;};
  toRON = import ./toRON.nix {inherit lib;};
  types = import ./types.nix;
in {
  inherit fromRON toRON;
  inherit (types) mkRON isRONType;

  importRON = path:
    lib.pipe path [
      builtins.readFile
      fromRON
    ];
}

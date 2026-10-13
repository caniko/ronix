{rustToolchain}: {pkgs, ...}: {
  projectRootFile = "flake.nix";
  programs.rustfmt = {
    enable = true;
    package = rustToolchain;
    edition = "2021";
  };
  programs.alejandra.enable = true;
}

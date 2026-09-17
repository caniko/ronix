{
  pkgs,
  treefmtWrapper,
  rustToolchain ? null,
}: {
  treefmt = {
    enable = true;
    name = "treefmt";
    package = treefmtWrapper;
    entry = "${treefmtWrapper}/bin/treefmt --fail-on-change";
    pass_filenames = false;
  };

  cargo-fmt = {
    enable = true;
    name = "cargo fmt";
    entry = "cargo fmt --all -- --check";
    extraPackages = pkgs.lib.optional (rustToolchain != null) rustToolchain;
    pass_filenames = false;
  };

  cargo-clippy = {
    enable = true;
    name = "cargo clippy";
    entry = "cargo clippy --all-targets --all-features -- --deny warnings";
    extraPackages = pkgs.lib.optional (rustToolchain != null) rustToolchain;
    pass_filenames = false;
  };

  cargo-msrv = {
    enable = true;
    name = "cargo check MSRV";
    entry = "${pkgs.rust-bin.stable."1.74.0".default}/bin/cargo check --workspace --all-features";
    extraPackages = [pkgs.rust-bin.stable."1.74.0".default];
    pass_filenames = false;
    stages = ["pre-push" "manual"];
  };

  cargo-audit = {
    enable = true;
    name = "cargo audit";
    entry = "cargo audit";
    extraPackages = pkgs.lib.optional (rustToolchain != null) rustToolchain ++ [pkgs.cargo-audit];
    pass_filenames = false;
  };

  nix-flake-check = {
    enable = true;
    name = "nix flake check";
    entry = "nix --extra-experimental-features 'nix-command flakes' flake check --cores 0 --max-jobs auto --no-update-lock-file";
    extraPackages = [pkgs.nix];
    pass_filenames = false;
    stages = ["manual"];
  };
}

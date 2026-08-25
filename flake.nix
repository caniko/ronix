{
  description = "ronix — RON ↔ Nix interop: serde serializer for Nix expressions + toRON/fromRON Nix library";

  inputs = {
    rs-harbor.url = "git+https://github.com/caniko/harbor-rs.git?ref=trunk&rev=05cc4f162b55fa904b687db1821e2463fa813e50";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    plinth = {
      url = "git+https://github.com/caniko/plinth.git?ref=refs/heads/trunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      rs-harbor,
      nixpkgs,
      crane,
      plinth,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [(import rs-harbor.inputs.rust-overlay)];
      };
      toolchainFor = system: rs-harbor.lib.mkToolchain { pkgs = pkgsFor system; toolchainProfile = "stable"; };
      craneLibFor = system: (toolchainFor system).craneLib;

      packageFor =
        system:
        let
          craneLib = craneLibFor system;
          pkgs = pkgsFor system;
          buildCache = rs-harbor.lib.mkBuildCachePolicy {
            inherit pkgs;
            sccachePackage = rs-harbor.packages.${system}.sccache;
            cacheRoot = null;
            namespaceScope = "canix-rust";
            namespaceGeneration = 5;
          };
        in
        buildCache.withRustCache { package = craneLib.buildPackage {
          pname = "ronix";
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
        }; };
    in
    {
      # ── Nix library ────────────────────────────────────────────────
      # Usage: ronix.lib.toRON, ronix.lib.fromRON, etc.
      lib = import ./nix/lib.nix { inherit (nixpkgs) lib; };

      # ── NixOS helpers ──────────────────────────────────────────────
      # Usage: ronix.nixosHelpers.mkRonService { ... }
      nixosHelpers = import ./nix/helpers.nix { ronixLib = self.lib; };

      # ── Overlay ────────────────────────────────────────────────────
      # Usage: nixpkgs.overlays = [ ronix.overlays.default ];
      overlays.default = _final: _prev: {
        ronix = self.packages.${_prev.stdenv.hostPlatform.system}.default;
      };

      # ── Packages ───────────────────────────────────────────────────
      packages = forSystems (system: {
        default = packageFor system;
        ronix = packageFor system;
        website = plinth.lib.${system}.mkProjectSite {
          pname = "ronix-website";
          domain = "ronix.tartanoglu.com";
          configPath = ./website/plinth-project.toml;
        };
        site = self.packages.${system}.website;
      });

      apps = forSystems (system: {
        deploy-pages = plinth.lib.${system}.mkDeployPagesApp {
          domain = "ronix.tartanoglu.com";
        };
      });

      # ── Checks (cargo test) ───────────────────────────────────────
      checks = forSystems (
        system:
        let
          craneLib = craneLibFor system;
          src = craneLib.cleanCargoSource ./.;
          commonArgs = {
            inherit src;
            pname = "ronix";
            strictDeps = true;
          };
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in
        {
          ronix-tests = craneLib.cargoTest (
            commonArgs
            // {
              inherit cargoArtifacts;
              cargoExtraArgs = "--all-features";
            }
          );

          ronix-clippy = craneLib.cargoClippy (
            commonArgs
            // {
              inherit cargoArtifacts;
              cargoExtraArgs = "--all-features";
              cargoClippyExtraArgs = "--all-targets -- -D warnings";
            }
          );

          ronix-fmt = craneLib.cargoFmt { inherit src; pname = "ronix"; };
        }
      );

      # ── Dev shell ──────────────────────────────────────────────────
      devShells = forSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [
              cargo
              rustc
              clippy
              rustfmt
            ];
          };
        }
      );
    };
}

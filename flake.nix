{
  description = "ronix — RON ↔ Nix interop: serde serializer for Nix expressions + toRON/fromRON Nix library";

  inputs = {
    harbor.url = "git+https://github.com/caniko/harbor.git?ref=feat/harbor-monorepo-components&rev=e8b1996580e4ecd51dd402edf4a16d9df88e3a1b";
    nixpkgs.follows = "harbor/nixpkgs";
    crane.follows = "harbor/crane";
    treefmt-nix.follows = "harbor/treefmt-nix";
    plinth = {
      url = "git+https://github.com/caniko/plinth.git?ref=migrate/harbor-combined-20261012-features&rev=534dfa6dd6217db97b7ccd313501120a3c34d912";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    harbor,
    nixpkgs,
    crane,
    plinth,
    treefmt-nix,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [(import harbor.inputs.rust-overlay)];
      };
    toolchainFor = system:
      harbor.lib.rust.mkToolchain {
        pkgs = pkgsFor system;
        toolchainProfile = "stable";
      };
    craneLibFor = system: (toolchainFor system).craneLib;
    treefmtFor = system:
      treefmt-nix.lib.evalModule (pkgsFor system) (import ./nix/treefmt.nix {
        rustToolchain = (toolchainFor system).rustToolchain;
      });

    packageFor = system: let
      craneLib = craneLibFor system;
      pkgs = pkgsFor system;
      buildCache = harbor.lib.rust.mkBuildCachePolicy {
        inherit pkgs;
        sccachePackage = harbor.packages.${system}.rust-sccache;
        cacheRoot = null;
        # Public CI uses a private build-local cache when managed transport is absent.
        ephemeralFallback = true;
        namespaceScope = "canix-rust";
        namespaceGeneration = 5;
      };
    in
      buildCache.withRustCache {
        package = craneLib.buildPackage {
          pname = "ronix";
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
        };
      };
  in {
    # ── Nix library ────────────────────────────────────────────────
    # Usage: ronix.lib.toRON, ronix.lib.fromRON, etc.
    lib = import ./nix/lib.nix {inherit (nixpkgs) lib;};

    # ── NixOS helpers ──────────────────────────────────────────────
    # Usage: ronix.nixosHelpers.mkRonService { ... }
    nixosHelpers = import ./nix/helpers.nix {ronixLib = self.lib;};

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
    formatter = forSystems (system: (treefmtFor system).config.build.wrapper);

    # ── Checks (cargo test) ───────────────────────────────────────
    checks = forSystems (
      system: let
        craneLib = craneLibFor system;
        src = craneLib.cleanCargoSource ./.;
        commonArgs = {
          inherit src;
          pname = "ronix";
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
      in {
        formatting = (treefmtFor system).config.build.check self;
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

        ronix-fmt = craneLib.cargoFmt {
          inherit src;
          pname = "ronix";
        };
      }
    );

    # ── Dev shell ──────────────────────────────────────────────────
    devShells = forSystems (
      system: let
        pkgs = pkgsFor system;
        shells = harbor.lib.rust.mkDevShells {
          inherit pkgs;
          craneLib = craneLibFor system;
          cross = harbor.lib.rust.mkCross {inherit pkgs system;};
          enableOsxcrossEnv = false;
          packages = [(treefmtFor system).config.build.wrapper];
        };
      in {
        inherit (shells) default;
      }
    );
  };
}

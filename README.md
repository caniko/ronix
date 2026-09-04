# ronix

<!-- simit:badges:start -->

[![CI](https://img.shields.io/badge/CI-managed-2088ff)](.github/workflows/ci.yaml) [![Nix](https://img.shields.io/badge/Nix-managed-5277c3)](flake.nix) [![crates.io](https://img.shields.io/badge/crates.io-ready-f46623)](https://crates.io/crates/ronix)

<!-- simit:badges:end -->

The bridge between [RON](https://github.com/ron-rs/ron/) and Nix.

A Rust library and Nix flake for bidirectional conversion between RON and Nix expressions. Serialize Rust structs to Nix attribute sets, parse RON strings into Nix, or go the other way with `toRON` / `fromRON` in pure Nix.

## Quick start

```toml
[dependencies]
ronix = "0.1"
serde = { version = "1", features = ["derive"] }
```

```rust
use serde::Serialize;

#[derive(Serialize)]
struct FanCurve {
    name: String,
    temp: u32,
    pwm: u8,
}

let curve = FanCurve { name: "cpu".into(), temp: 60, pwm: 150 };
let nix = ronix::to_nix(&curve).unwrap();
// {
//   name = "cpu";
//   temp = 60;
//   pwm = 150;
// }
```

## API

| Function | Description |
|---|---|
| `to_nix(value)` | Serialize any `Serialize` type to a Nix expression string |
| `to_nix_module(value, attr_path)` | Same, wrapped in a NixOS module (`_: { attr.path = …; }`) |
| `ron_to_nix(ron)` | Parse a RON string and convert to Nix |
| `ron_to_nix_module(ron, attr_path)` | Parse RON and wrap in a NixOS module |
| `escape_nix_string(s)` | Escape a string for embedding in Nix |

### RON → Nix

```rust
let nix = ronix::ron_to_nix(r#"(poll_ms: 2000, name: "hello")"#).unwrap();
assert!(nix.contains("poll_ms = 2000;"));
```

### NixOS modules

```rust
let nix = ronix::to_nix_module(&config, "services.myapp.settings").unwrap();
// _: {
//   services.myapp.settings = {
//     ...
//   };
// }
```

### CLI helpers

Enable the `cli` feature to get a reusable clap argument struct you can embed in your own binary:

```toml
[dependencies]
ronix = { version = "0.1", features = ["cli"] }
clap = { version = "4", features = ["derive"] }
```

```rust
use clap::Parser;

#[derive(Parser)]
struct MyCli {
    #[command(flatten)]
    ronix: ronix::cli::RonixArgs,
}

fn main() -> Result<(), ronix::Error> {
    let cli = MyCli::parse();
    cli.ronix.execute()
}
```

## Nix library

ronix provides a pure-Nix library for converting between Nix values and RON. Add the flake as an input and use the library directly:

```nix
{
  inputs.ronix.url = "github:caniko/ronix";

  outputs = { ronix, ... }: {
    # Nix → RON
    ronString = ronix.lib.toRON 0 {
      name = "hello";
      count = 42;
    };

    # RON → Nix
    nixValue = ronix.lib.fromRON ''(name: "hello", count: 42)'';

    # Read a .ron file directly
    config = ronix.lib.importRON ./config.ron;
  };
}
```

### Type constructors

The Nix library uses `mkRON` to represent RON types that have no direct Nix equivalent:

```nix
{ mkRON, ... }: {
  char   = mkRON.char "A";
  opt    = mkRON.optional "value";    # Some("value")
  none   = mkRON.optional null;       # None
  tuple  = mkRON.tuple [ 1 2 3 ];
  enum_  = mkRON.enum "Variant" [ ];  # unit variant
  map    = mkRON.map [ { key = "a"; value = 1; } ];
}
```

### NixOS service helper

```nix
{ ronix, ... }: {
  config = ronix.nixosHelpers.mkRonService {
    name = "smartcool";
    package = pkgs.smartcool;
    settings = { temp_target = 65; fan_mode = "auto"; };
    execStart = "${pkgs.smartcool}/bin/sc daemon -c /etc/smartcool/config.ron";
  };
}
```

This generates `/etc/smartcool/config.ron` and a matching systemd service.

## Supported types

| Rust / RON | Nix output |
|---|---|
| `bool` | `true` / `false` |
| integers | `42`, `-7` |
| floats | `2.5`, `1.0` |
| `String` / `&str` | `"hello"` (with proper escaping) |
| `Vec<T>` / sequences | `[ ... ]` |
| structs / maps | `{ key = value; ... }` |
| `Option<T>` | `Some` unwraps, `None` omits the field |
| `char` | `"c"` |

Nix interpolation syntax (`${...}`) is automatically escaped.

## Building with Nix

```sh
nix build    # build the crate
nix flake check   # run tests, clippy, and fmt
nix develop  # enter a dev shell with cargo, clippy, rustfmt
```

## CI

GitHub Actions runs `nix flake check` (tests, clippy, and fmt) on every push and pull request.

## License

[MIT](LICENSE)

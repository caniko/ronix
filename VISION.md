# ronix vision

ronix is the bridge between RON and Nix. It is a Rust library plus a Nix flake
that converts in both directions: serialize any `Serialize` value into a Nix
expression (optionally wrapped as a NixOS module), parse a RON string into Nix,
and convert Nix values to and from RON from pure Nix with `toRON`, `fromRON`,
`importRON`, `mkRON` and `isRONType`.

## Problem

Configuration usually has two incompatible neighbourhoods: applications whose
settings are defined by Rust types, and NixOS modules that expect attribute
sets. Hand-copying values between them drifts immediately. ronix lets the Rust
type stay the definition — a custom serde `Serializer` emits Nix from the same
value the application uses — and lets Nix read RON files directly for the
reverse direction, including a `mkRonService` helper that generates a systemd
service from RON data.

## Principles

- **Typed source, Nix output.** The serializer walks any `Serialize` type, so
  the Rust struct remains the single definition of the config shape.
- **Both directions are first class.** Rust to Nix and RON to Nix exist as
  library functions, and Nix to RON exists as a pure-Nix library, so a project
  can pick whichever side authors its config.
- **Module wrapping is built in.** `to_nix_module` and `ron_to_nix_module` emit
  `_: { attr.path = ...; }`, which is what a NixOS module expects, instead of
  making every caller write the wrapper.
- **Escaping is an explicit API.** `escape_nix_string` is public because
  embedding arbitrary strings in Nix is a real failure mode.
- **Nix types without a direct equivalent get a constructor.** `mkRON`
  represents RON types that Nix does not model natively rather than silently
  flattening them.
- **Never silently lose Nix map keys.** A recent fix preserves reserved Nix map
  keys, and an earlier one fixed key stripping when a key is invalid — the
  error cases are treated as bugs, not as unavoidable lossy conversion.

## Scope

In scope: the serde serializer to Nix, RON string parsing to Nix, module
wrapping, string escaping, the optional `cli` feature with reusable clap
arguments (`RonixArgs`) for tools that expose this conversion, the pure-Nix
library (`lib.toRON`/`fromRON`/`importRON`/`mkRON`/`isRONType`), and the
`mkRonService` NixOS helper.

## Non-goals

- Not a general configuration framework or a NixOS module generator beyond the
  single-attribute module wrapper and the service helper.
- The pure-Nix `fromRON` parser is marked experimental in its own source; it
  handles the RON constructs it models (lists, maps, structs, tuples, enums,
  optionals, chars, floats, integers, strings and a raw fallback) and is not
  presented as a complete RON implementation.

## Direction

Recent commits are fixes to conversion fidelity (`fix: preserve reserved Nix map
keys`, `fix key stripping when invalid`) followed by infrastructure migration to
GitHub with Harbor/Simit inputs. The current branch, `key-strip-fix`, names the
same thread: what happens to keys the converter cannot keep verbatim. No
published roadmap beyond the 0.1.0 release exists.

## Place in the fleet

Canix runs ronix as a Simit updater target on atlas so its flake and generated
CI follow the fleet. It is published on crates.io as `ronix` and its Nix library
is meant to be consumed as a flake input by hosts that keep RON config data.

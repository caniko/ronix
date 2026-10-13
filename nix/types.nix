# ronix — RON type constructors and predicates.
#
# mkRON: build typed RON wrappers (char, enum, map, namedStruct, optional, raw, tuple).
# isRONType: check whether a value is a valid ronix __type wrapper.
let
  inherit (builtins) attrNames isAttrs;
  inherit (import ./internal.nix) mkAssertion mkThrow;
in {
  isRONType = v:
    v ? __type
    && (
      (
        (
          v.__type
          == "char"
          || v.__type == "map"
          || v.__type == "optional"
          || v.__type == "raw"
          || v.__type == "tuple"
        )
        && v ? value
      )
      || (v.__type == "namedStruct" && v ? name && v ? value)
      || (v.__type == "enum" && (v ? variant || (v ? variant && v ? value)))
    );

  mkRON = type: value:
    {
      char = {
        __type = "char";
        inherit value;
      };

      enum =
        if isAttrs value
        then
          assert mkAssertion "mkRON" (
            attrNames value
            == [
              "value"
              "variant"
            ]
          ) "enum type must receive a string or an attribute set with value and variant keys"; {
            __type = "enum";
            inherit (value) value variant;
          }
        else {
          __type = "enum";
          variant = value;
        };

      map = {
        __type = "map";
        inherit value;
      };

      namedStruct = assert mkAssertion "mkRON" (
        isAttrs value
        && attrNames value
        == [
          "name"
          "value"
        ]
      ) "namedStruct type must receive an attribute set with name and value keys."; {
        __type = "namedStruct";
        inherit (value) name value;
      };

      optional = {
        __type = "optional";
        inherit value;
      };

      raw = {
        __type = "raw";
        inherit value;
      };

      tuple = {
        __type = "tuple";
        inherit value;
      };
    }
    .${
      type
    } or (mkThrow "mkRON" "${type} is not supported.");
}

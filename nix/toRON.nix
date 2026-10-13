# ronix — Nix value → RON string serializer.
#
# Pretty-prints Nix values (including ronix __type wrappers) as RON syntax.
{lib}: let
  inherit
    (builtins)
    all
    attrNames
    head
    isAttrs
    isList
    isString
    length
    match
    typeOf
    ;
  inherit
    (lib)
    boolToString
    concatImapStringsSep
    hasInfix
    optionalString
    pipe
    ;
  inherit (lib.strings) escapeNixString floatToString replicate;
  inherit (import ./internal.nix) mkAssertion mkThrow;

  toRON' = startIndent: value: let
    type = typeOf value;
    nextIndent = startIndent + 1;

    indent = level: replicate level "    ";
  in
    {
      bool = boolToString value;

      float = let
        trimFloatString = float: let
          string = floatToString float;
        in
          if hasInfix "." string
          then head (match "([0-9]+[.][0-9]*[1-9]|[0-9]+[.]0)0*" string)
          else string;
      in
        trimFloatString value;

      int = toString value;
      lambda = mkThrow "toRON" "Functions are not supported in RON";

      list = let
        count = length value;
      in
        if count == 0
        then "[]"
        else "[\n${
          concatImapStringsSep "\n" (
            index: element: "${indent nextIndent}${toRON' nextIndent element}${optionalString (index != count) ","}"
          )
          value
        },\n${indent startIndent}]";

      null = mkThrow "toRON" "Null values are not supported in RON. Use the optional type for nullable values.";

      path = pipe value [
        toString
        escapeNixString
      ];

      set =
        if value ? __type
        then
          if value.__type == "raw"
          then
            assert mkAssertion "toRON" (value ? value) "raw type must have a value.";
            assert mkAssertion "toRON" (isString value.value) "raw type value must be a string.";
              value.value
          else if value.__type == "optional"
          then
            assert mkAssertion "toRON" (value ? value) "optional type must have a value.";
              if value.value == null
              then "None"
              else "Some(${toRON' startIndent value.value})"
          else if value.__type == "char"
          then
            assert mkAssertion "toRON" (value ? value) "char type must have a value.";
            assert mkAssertion "toRON" (isString value.value) "char type value must be a string.";
            assert mkAssertion "toRON" (
              builtins.stringLength value.value == 1
            ) "char type value must be a single character string."; "'${value.value}'"
          else if value.__type == "enum"
          then
            assert mkAssertion "toRON" (value ? variant) "enum type must have a variant.";
            assert mkAssertion "toRON" (isString value.variant) "enum type variant must be a string value.";
              if value ? value
              then
                assert mkAssertion "toRON" (isList value.value) "enum type must have a list of values."; let
                  count = length value.value;
                in
                  if count == 0
                  then "${value.variant}()"
                  else "${value.variant}(\n${
                    concatImapStringsSep "\n" (
                      index: element: "${indent nextIndent}${toRON' nextIndent element}${optionalString (index != count) ","}"
                    )
                    value.value
                  },\n${indent startIndent})"
              else value.variant
          else if value.__type == "map"
          then
            assert mkAssertion "toRON" (value ? value) "map type must have a value.";
            assert mkAssertion "toRON" (isList value.value) "map type value must be a list.";
            assert mkAssertion "toRON" (all isAttrs value.value)
            "map type value must be a list of attribute sets."; let
              count = length value.value;
            in
              if count == 0
              then "{}"
              else "{\n${
                concatImapStringsSep "\n" (
                  index: entry:
                    assert mkAssertion "toRON" (
                      let
                        keys = attrNames entry;
                      in
                        keys
                        == [
                          "key"
                          "value"
                        ]
                    ) "map type entry must have only 'key' and 'value' attributes."; "${indent nextIndent}${toRON' nextIndent entry.key}: ${toRON' nextIndent entry.value}${
                      optionalString (index != count) ","
                    }"
                )
                value.value
              },\n${indent startIndent}}"
          else if value.__type == "tuple"
          then
            assert mkAssertion "toRON" (value ? value) "tuple type must have a value.";
            assert mkAssertion "toRON" (isList value.value) "tuple type value must be a list."; let
              count = length value.value;
            in
              if count == 0
              then "()"
              else "(\n${
                concatImapStringsSep "\n" (
                  index: element: "${indent nextIndent}${toRON' nextIndent element}${optionalString (index != count) ","}"
                )
                value.value
              },\n${indent startIndent})"
          else if value.__type == "namedStruct"
          then
            assert mkAssertion "toRON" (value ? name) "namedStruct type must have a name.";
            assert mkAssertion "toRON" (isString value.name) "namedStruct type name must be a string.";
            assert mkAssertion "toRON" (value ? value) "namedStruct type must have a value.";
            assert mkAssertion "toRON" (isAttrs value.value) "namedStruct type value must be a attribute set."; let
              keys = attrNames value.value;
              count = length keys;
            in
              if count == 0
              then "${value.name}()"
              else "${value.name}(\n${
                concatImapStringsSep "\n" (
                  index: key: "${indent nextIndent}${key}: ${toRON' nextIndent value.value.${key}}${
                    optionalString (index != count) ","
                  }"
                )
                keys
              },\n${indent startIndent})"
          else mkThrow "toRON" "set type ${toString value.__type} is not supported."
        else let
          keys = attrNames value;
          count = length keys;
        in
          if count == 0
          then "()"
          else "(\n${
            concatImapStringsSep "\n" (
              index: key: "${indent nextIndent}${key}: ${toRON' nextIndent value.${key}}${
                optionalString (index != count) ","
              }"
            )
            keys
          },\n${indent startIndent})";

      string = escapeNixString value;
    }
    .${
      type
    } or (mkThrow "toRON" "${type} is not supported.");
in
  toRON'

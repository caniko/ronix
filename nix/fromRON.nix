# ronix — RON string → Nix value parser.
#
# Experimental. Handles lists, maps, structs, tuples, enums, optionals,
# chars, floats, integers, strings, and raw fallback values.
{ lib }:
let
  inherit (builtins)
    fromJSON
    head
    listToAttrs
    match
    substring
    stringLength
    ;
  inherit (lib)
    foldl
    last
    pipe
    splitString
    stringToCharacters
    toInt
    trim
    ;

  fromRON' =
    str:
    let
      trimmed = trim str;

      firstChar = substring 0 1 trimmed;
      lastChar = substring (stringLength trimmed - 1) 1 trimmed;

      splitItems =
        str:
        let
          content = pipe str [
            trim
            (substring 1 (stringLength str - 2))
            trim
          ];

          split =
            acc: current: depth: rest:
            if rest == "" then
              if current != "" then acc ++ [ (trim current) ] else acc
            else
              let
                char = substring 0 1 rest;
                remaining = substring 1 (-1) rest;
              in
              if char == "(" || char == "[" || char == "{" then
                split acc (current + char) (depth + 1) remaining
              else if char == ")" || char == "]" || char == "}" then
                split acc (current + char) (depth - 1) remaining
              else if char == "," && depth == 0 then
                split (acc ++ [ (trim current) ]) "" depth remaining
              else
                split acc (current + char) depth remaining;
        in
        split [ ] "" 0 content;

      findFirstColon =
        str:
        let
          helper =
            pos: depth:
            if pos >= stringLength str then
              null
            else
              let
                char = substring pos 1 str;
              in
              if char == "(" || char == "[" || char == "{" then
                helper (pos + 1) (depth + 1)
              else if char == ")" || char == "]" || char == "}" then
                helper (pos + 1) (depth - 1)
              else if char == ":" && depth == 0 then
                pos
              else
                helper (pos + 1) depth;
        in
        helper 0 0;

      isStruct =
        str:
        let
          content = pipe str [
            trim
            (substring 1 (stringLength str - 2))
            trim
          ];
          colonPos = findFirstColon content;

          beforeColon = substring 0 colonPos content;
          depth = foldl (
            acc: char:
            if char == "(" || char == "[" || char == "{" then
              acc + 1
            else if char == ")" || char == "]" || char == "}" then
              acc - 1
            else
              acc
          ) 0 (stringToCharacters beforeColon);
        in
        colonPos != null && depth == 0;
    in
    if firstChar == "[" && lastChar == "]" then
      map fromRON' (splitItems trimmed)
    else if firstChar == "{" && lastChar == "}" then
      {
        __type = "map";
        value = map (
          item:
          let
            colonPos = findFirstColon item;
            key = trim (substring 0 colonPos item);
            value = trim (substring (colonPos + 1) (-1) item);
          in
          {
            key = fromRON' key;
            value = fromRON' value;
          }
        ) (splitItems trimmed);
      }
    else if trimmed == "None" then
      {
        __type = "optional";
        value = null;
      }
    else if match "Some\\(.*\\)" trimmed != null then
      let
        value = head (match "Some\\((.*)\\)" trimmed);
      in
      {
        __type = "optional";
        value = fromRON' value;
      }
    else if trimmed == "true" then
      true
    else if trimmed == "false" then
      false
    else if firstChar == "(" && lastChar == ")" then
      if isStruct trimmed then
        listToAttrs (
          map (
            item:
            let
              colonPos = findFirstColon item;
              name = trim (substring 0 colonPos item);
              value = trim (substring (colonPos + 1) (-1) item);
            in
            {
              inherit name;
              value = fromRON' value;
            }
          ) (splitItems trimmed)
        )
      else
        {
          __type = "tuple";
          value = map fromRON' (splitItems trimmed);
        }
    else if match "[A-Za-z_][A-Za-z0-9_]*\\(.*\\)" trimmed != null then
      let
        matches = match "([A-Za-z_][A-Za-z0-9_]*)(\\(.*\\))" trimmed;
        name = trim (head matches);
        value = trim (last matches);
      in
      if isStruct value then
        {
          __type = "namedStruct";
          inherit name;
          value = fromRON' value;
        }
      else
        {
          __type = "enum";
          variant = name;
          value = map fromRON' (splitItems value);
        }
    else if match "-?[0-9]+[.][0-9]+" trimmed != null then
      let
        decimals = pipe trimmed [
          (splitString ".")
          last
          stringLength
        ];
      in
      if decimals > 5 then
        {
          __type = "raw";
          value = trimmed;
        }
      else
        fromJSON trimmed
    else if match "-?[0-9]+" trimmed != null then
      toInt trimmed
    else if match "'.'" trimmed != null then
      {
        __type = "char";
        value = substring 1 1 trimmed;
      }
    else if match ''".*"'' trimmed != null then
      fromJSON trimmed
    else
      {
        __type = "raw";
        value = trimmed;
      };
in
lib.warn "ronix.fromRON: This function is experimental. Please report issues at https://github.com/caniko/ronix"
  fromRON'

import std/strutils

const PathSignatureTable = block:
  var arr: array[256, uint8]
  for i in 0 ..< 256:
    if i <= 0x20 or i == 0x22 or i == 0x23 or i == 0x3c or i == 0x3e or i == 0x3f or
        i == 0x5e or i == 0x60 or i == 0x7b or i == 0x7d or i > 0x7e:
      arr[i] = 1
    elif i == 0x25:
      arr[i] = 8
    elif i == 0x2e:
      arr[i] = 4
    elif i == 0x5c:
      arr[i] = 2

  ensureMove(arr)

func pathSignature*(input: string): uint8 {.inline, raises: [].} =
  # The path percent-encode set is the query percent-encode set and U+003F (?),
  # U+0060 (`), U+007B ({), and U+007D (}). The query percent-encode set is the
  # C0 control percent-encode set and U+0020 SPACE, U+0022 ("), U+0023 (#),
  # U+003C (<), and U+003E (>). The C0 control percent-encode set are the C0
  # controls and all code points greater than U+007E (~).
  var i = 0
  var accum: uint8

  while i + 7 < input.len:
    accum =
      accum or (
        PathSignatureTable[cast[uint8](input[i])] or
        PathSignatureTable[cast[uint8](input[i + 1])] or
        PathSignatureTable[cast[uint8](input[i + 2])] or
        PathSignatureTable[cast[uint8](input[i + 3])] or
        PathSignatureTable[cast[uint8](input[i + 4])] or
        PathSignatureTable[cast[uint8](input[i + 5])] or
        PathSignatureTable[cast[uint8](input[i + 6])] or
        PathSignatureTable[cast[uint8](input[i + 7])]
      )
    i += 8

  while i < input.len:
    accum = accum or cast[uint8](PathSignatureTable[cast[uint8](input[i])])
    inc i

  ensureMove(accum)

func isWindowsDriveLetter*(input: string): bool {.inline.} =
  input.len >= 2 and
    (isAlphaAscii(input[0]) and ((input[1] == ':') or (input[1] == '|'))) and (
    (input.len == 2) or
    (input[2] == '/' or input[2] == '\\' or input[2] == '?' or input[2] == '#')
  )

## Helper routines for the parser
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[options]
from std/strutils import Letters, Digits
import pkg/url/[constants, types]
import pkg/kaleidoscope/search
import pkg/shakar

export Letters, Digits

const
  AlnumPlus = Letters + Digits + {'+', '-', '.'}
  AuthorityDelimiterSpecial = block:
    var arr: array[256, uint8]
    arr[cast[uint8]('@')] = 1
    arr[cast[uint8]('/')] = 1
    arr[cast[uint8]('\\')] = 1
    arr[cast[uint8]('?')] = 1

    ensureMove(arr)

  AuthorityDelimiter = block:
    var arr: array[256, uint8]
    arr[cast[uint8]('@')] = 1
    arr[cast[uint8]('/')] = 1
    arr[cast[uint8]('?')] = 1

    ensureMove(arr)

  SpecialHostDelimiters = block:
    var arr: array[256, uint8]
    arr[cast[uint8](':')] = 1
    arr[cast[uint8]('/')] = 1
    arr[cast[uint8]('[')] = 1
    arr[cast[uint8]('\\')] = 1
    arr[cast[uint8]('?')] = 1

    ensureMove(arr)

  IsForbiddenDomainCodePointTable = block:
    var arr: array[256, uint8]
    arr[cast[uint8]('\0')] = 1
    arr[cast[uint8]('\x09')] = 1
    arr[cast[uint8]('\x0a')] = 1
    arr[cast[uint8]('\x0d')] = 1
    arr[cast[uint8](' ')] = 1
    arr[cast[uint8]('#')] = 1
    arr[cast[uint8]('/')] = 1
    arr[cast[uint8](':')] = 1
    arr[cast[uint8]('<')] = 1
    arr[cast[uint8]('>')] = 1
    arr[cast[uint8]('?')] = 1
    arr[cast[uint8]('@')] = 1
    arr[cast[uint8]('[')] = 1
    arr[cast[uint8]('\\')] = 1
    arr[cast[uint8](']')] = 1
    arr[cast[uint8]('^')] = 1
    arr[cast[uint8]('|')] = 1
    arr[cast[uint8]('%')] = 1

    ensureMove(arr)

func trimC0Whitespace*(input: var Input) {.raises: [].} =
  while input.len > 0 and input[0].isC0ControlOrSpace:
    input = input[1 ..< input.len]

  while input.len > 0 and input[input.len - 1].isC0ControlOrSpace:
    input = input[0 ..< input.len - 1]

func isAlnumPlus*(c: uint8 | char): bool {.inline, raises: [].} =
  cast[char](c) in AlnumPlus

func isAsciiHexDigit*(c: uint8 | char): bool {.inline, raises: [].} =
  (c >= '0' and c <= '9') or (c >= 'A' and c <= 'F') or (c >= 'a' and c <= 'f')

proc pruneFragment*(input: var Input): Option[string] {.raises: [].} =
  # This should be fairly fast since it uses Kaleidoscope.
  # That'll use AVX2 or SSE4.1 when possible, and fall back
  # to a scalar implementation on other platforms.
  let locationOfFirst = input.find("#")
  if locationOfFirst == -1:
    return none(string)

  let fragment = input[locationOfFirst + 1 ..< input.len]
  input = input[0 ..< locationOfFirst] # Then, we can occlude the fragment's contents

  some(fragment)

func findAuthorityDelimiterSpecial*(view: string): uint64 {.raises: [].} =
  for pos, c in view:
    if AuthorityDelimiterSpecial[cast[uint8](c)] == 1:
      return uint64(pos)

  uint64(view.len)

func findAuthorityDelimiter*(view: string): uint64 {.raises: [].} =
  for pos, c in view:
    if AuthorityDelimiter[cast[uint8](c)] == 1:
      return uint64(pos)

  uint64(view.len)

func findNextHostDelimiterSpecial*(view: string, location: uint64): uint64 =
  # TODO: Implement AVX2/SSE4.1/NEON variants
  # For now, this table approach should suffice.
  let str = view[location ..< view.len]
  for pos, c in str:
    if SpecialHostDelimiters[cast[uint8](c)] == 1:
      return uint64(pos) + location

  uint64(view.len)

func getHostDelimiterFunction*(
    isSpecial: bool, view: string
): tuple[location: uint64, foundColon: bool] =
  # The spec at https://url.spec.whatwg.org/#hostname-state expects us to
  # compute a variable called insideBrackets but this variable is only used
  # once, to check whether a ':' character was found outside brackets. Exact
  # text: "Otherwise, if c is U+003A (:) and insideBrackets is false, then:".
  # It is conceptually simpler and arguably more efficient to just return a
  # Boolean indicating whether ':' was found outside brackets.
  let size = uint64(view.len)
  var location = 0'u64
  var foundColon = false

  if isSpecial:
    location = findNextHostDelimiterSpecial(view, location)

    while location < size:
      if view[location] == '[':
        location = cast[uint64](view[location ..< view.len].find(']'))
        if location == cast[uint64](-1):
          location = size
          break
      else:
        foundColon = view[location] == ':'
        break

      location = findNextHostDelimiterSpecial(view, location)
  else:
    unreachable

  (location: location, foundColon: foundColon)

func containsForbiddenDomainCodePoint*(input: string): uint8 {.raises: [].} =
  var i = 0
  var accum: uint8

  while i + 4 < input.len:
    accum = accum or IsForbiddenDomainCodePointTable[cast[uint8](input[i])]
    accum = accum or IsForbiddenDomainCodePointTable[cast[uint8](input[i + 1])]
    accum = accum or IsForbiddenDomainCodePointTable[cast[uint8](input[i + 2])]
    accum = accum or IsForbiddenDomainCodePointTable[cast[uint8](input[i + 3])]
    i += 4

  while i < input.len:
    accum = accum or IsForbiddenDomainCodePointTable[cast[uint8](input[i])]
    inc i

  ensureMove(accum)

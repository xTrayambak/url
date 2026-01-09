## Helper routines for the parser
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[math, options, strutils]
import pkg/url/[constants, checkers, types, views]
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

  HostDelimiters = block:
    var arr: array[256, uint8]
    arr[cast[uint8](':')] = 1'u8
    arr[cast[uint8]('/')] = 1'u8
    arr[cast[uint8]('?')] = 1'u8
    arr[cast[uint8]('[')] = 1'u8

    ensureMove(arr)

func trimC0Whitespace*(input: var StringView) {.raises: [].} =
  while input.len > 0 and input[0].isC0ControlOrSpace:
    # input = input[1 ..< input.len]
    input.removePrefix(1)

  while input.len > 0 and input[input.len - 1].isC0ControlOrSpace:
    # input = input[0 ..< input.len - 1]
    input.removeSuffix(1)

func isAlnumPlus*(c: uint8 | char): bool {.inline, raises: [], cdecl.} =
  cast[char](c) in AlnumPlus

func isAsciiHexDigit*(c: uint8 | char): bool {.inline, raises: [], cdecl.} =
  (c >= '0' and c <= '9') or (c >= 'A' and c <= 'F') or (c >= 'a' and c <= 'f')

func pruneFragment*(input: var StringView): Option[string] {.raises: [], cdecl.} =
  let locationOfFirst = find(input, '#')
  if locationOfFirst == -1:
    return none(string)

  let fragment = input.slice(cast[uint32](locationOfFirst + 1), input.len)
  input = input.slice(0, cast[uint32](locationOfFirst))
    # Then, we can occlude the fragment's contents

  some($fragment)

func findAuthorityDelimiterSpecial*(view: StringView): uint32 {.raises: [].} =
  for pos, c in view:
    if AuthorityDelimiterSpecial[cast[uint8](c)] == 1:
      return uint32(pos)

  view.len

func findAuthorityDelimiter*(view: StringView): uint32 {.raises: [].} =
  for pos, c in view:
    if AuthorityDelimiter[cast[uint8](c)] == 1:
      return uint32(pos)

  view.len

when defined(nimUrlUseSse2):
  import std/bitops
  import pkg/nimsimd/sse2

  func builtin_ctzl(x: uint64): int32 {.importc: "__builtin_ctzl".}

  func findNextHostDelimiterSpecial*(view: StringView, location: uint32): uint32 =
    # First check for short strings in which case we do it naively.
    let size = view.len
    if size - location < 16:
      # Slow path
      for i in location ..< size:
        if view[i] == ':' or view[i] == '/' or view[i] == '\\' or view[i] == '?' or
            view[i] == '[':
          return uint32(i)

      return size

    # Fast path for longer strings
    var i = location
    let
      mask1 = mm_set1_epi8(':')
      mask2 = mm_set1_epi8('/')
      mask3 = mm_set1_epi8('\\')
      mask4 = mm_set1_epi8('?')
      mask5 = mm_set1_epi8('[')

    while i + 15 < size:
      let
        word = mm_loadu_si128(cast[ptr M128i](view[i].addr))
        m1 = mm_cmpeq_epi8(word, mask1)
        m2 = mm_cmpeq_epi8(word, mask2)
        m3 = mm_cmpeq_epi8(word, mask3)
        m4 = mm_cmpeq_epi8(word, mask4)
        m5 = mm_cmpeq_epi8(word, mask5)

        m = mm_or_si128(mm_or_si128(mm_or_si128(m1, m2), mm_or_si128(m3, m4)), m5)

      let mask: int32 = mm_movemask_epi8(m)
      if mask != 0:
        return i + cast[uint32](builtin_ctzl(cast[uint64](mask)))

      i += 16

    if i < size:
      let
        word = mm_loadu_si128(cast[ptr M128i](view[size - 16].addr))
        m1 = mm_cmpeq_epi8(word, mask1)
        m2 = mm_cmpeq_epi8(word, mask2)
        m3 = mm_cmpeq_epi8(word, mask3)
        m4 = mm_cmpeq_epi8(word, mask4)
        m5 = mm_cmpeq_epi8(word, mask5)

        m = mm_or_si128(mm_or_si128(mm_or_si128(m1, m2), mm_or_si128(m3, m4)), m5)

      let mask: int32 = mm_movemask_epi8(m)
      if mask != 0:
        return size - 16 + cast[uint32](builtin_ctzl(cast[uint64](mask)))

    size
else:
  func findNextHostDelimiterSpecial*(
      view: StringView, location: uint32
  ): uint32 {.inline.} =
    let str = view.slice(location, view.len - 1)
    for pos, c in str:
      if SpecialHostDelimiters[cast[uint8](c)] == 1:
        return cast[uint32](pos) + location

    view.len

func findNextHostDelimiter*(view: StringView, location: uint32): uint32 {.inline.} =
  let str = view.slice(location, view.len - 1)
  for pos, c in str:
    if HostDelimiters[cast[uint8](c)] == 1:
      return cast[uint32](pos) + location

  view.len

func getHostDelimiterFunction*(
    isSpecial: bool, view: StringView
): tuple[location: uint32, foundColon: bool] =
  # The spec at https://url.spec.whatwg.org/#hostname-state expects us to
  # compute a variable called insideBrackets but this variable is only used
  # once, to check whether a ':' character was found outside brackets. Exact
  # text: "Otherwise, if c is U+003A (:) and insideBrackets is false, then:".
  # It is conceptually simpler and arguably more efficient to just return a
  # Boolean indicating whether ':' was found outside brackets.
  let size = view.len
  var location = 0'u32
  var foundColon = false

  if isSpecial:
    location = findNextHostDelimiterSpecial(view, location)

    while location < size:
      if view[location] == '[':
        let pos = view.slice(location, view.len - 1).find(']')
        if pos == -1:
          location = size
          break

        location = location + cast[uint32](pos)
      else:
        foundColon = view[location] == ':'
        break

      location = findNextHostDelimiterSpecial(view, location)
  else:
    # We move to the next delimiter.
    location = findNextHostDelimiter(view, location)

    while location < size:
      if view[location] == '[':
        let tmpLoc = view.slice(location, view.len).find(']')
        if tmpLoc == -1:
          location = size
          break
        else:
          location = location + cast[uint32](tmpLoc)
      else:
        foundColon = view[location] == ':'
        break

      location = findNextHostDelimiter(view, location)

  # let target = int(size - location)
  # view.delete(target, target)
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

func shortenPath*(path: var string, typ: SchemeType): bool {.inline, raises: [].} =
  # Let path be url's path.
  # If url's scheme is "file", path's size is 1 and path[0] is a normalized
  # Windows drive letter, then return.
  if typ == SchemeType.File and path.find('/') == -1 and path.len > 0:
    if isNormalizedWindowsDriveLetter(path[1 ..< path.len]):
      return false

  # Remove path's last item, if any.
  let lastDelim = path.rfind('/')
  if lastDelim != -1:
    path.delete(lastDelim, lastDelim)
    return true

  false

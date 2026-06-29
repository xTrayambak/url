## Helper routines for the parser
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[math, options, strutils]
import pkg/url/[constants, checkers, search, types, views]
import pkg/[overdrive]

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

func isTabsOrNewline*(c: char): bool {.inline, raises: [], cdecl.} =
  c == '\r' or c == '\n' or c == '\t'

func trimC0Whitespace*(input: var StringView) {.raises: [].} =
  while input.len > 0 and input[0].isC0ControlOrSpace:
    # input = input[1 ..< input.len]
    input.removePrefix(1)

  while input.len > 0 and input[input.len - 1].isC0ControlOrSpace:
    # input = input[0 ..< input.len - 1]
    input.removeSuffix(1)

func isAlnumPlus*(c: uint8 | char): bool {.inline, raises: [], cdecl.} =
  cast[char](c) in AlnumPlus

func pruneFragment*(input: var StringView): Option[string] {.raises: [], cdecl.} =
  let locationOfFirst = findInsensitive(input, '#')
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

func removeAsciiTabOrNewline*(input: string): string =
  var buffer = newStringOfCap(input.len)
    # There is atleast one ASCII tab or newline if this routine is called.

  for c in input:
    if not isTabsOrNewline(c):
      buffer &= c

  ensureMove(buffer)

when getBackend() != VInstSet.Scalar and not defined(nimUrlNoSimd):
  func builtin_ctzl(x: uint64): int32 {.importc: "__builtin_ctzl".}

  func hasTabsOrNewline*(view: views.StringView): bool {.inline.} =
    const cap = when hasAvx2: 31'u32 else: 15'u32

    if view.len < cap or getBackend() == VInstSet.Scalar:
      # Slow path
      for c in view:
        if isTabsOrNewline(c):
          return true

      return false

    # Fast path
    var i = 0'u32
    var mask1, mask2, mask3: Vector[uint8]
    mask1.store(cast[uint8]('\r'))
    mask1.store(cast[uint8]('\n'))
    mask1.store(cast[uint8]('\t'))

    var running: Vector[uint8]
    while i + cap < view.len:
      var word: Vector[uint8]
      word.store(cast[ptr uint8](view[i].addr))
      running = ((word == mask1) or (word == mask2)) or (word == mask3)

      i += (cap + 1)

    if i < view.len:
      var word: Vector[uint8]
      word.store(cast[ptr uint8](view[view.len - cap].addr))
      running = ((word == mask1) or (word == mask2)) or (word == mask3)

    moveMask(running) != 0'i32

  func findNextHostDelimiterSpecial*(view: views.StringView, location: uint32): uint32 =
    # First check for short strings in which case we do it naively.
    let size = view.len
    if size - location < 16:
      # Slow path
      for i in location ..< size:
        if view[i] == ':' or view[i] == '/' or view[i] == '\\' or view[i] == '?' or
            view[i] == '[':
          return uint32(i)

      return size

    const cap = when hasAvx2: 31'u32 else: 15'u32

    # Fast path for longer strings
    var i = location
    var mask1, mask2, mask3, mask4, mask5: Vector[uint8]
    mask1.store(cast[uint8](':'))
    mask2.store(cast[uint8]('/'))
    mask3.store(cast[uint8]('\\'))
    mask4.store(cast[uint8]('?'))
    mask5.store(cast[uint8]('['))

    while i + cap < size:
      var word: Vector[uint8]
      word.store(cast[ptr uint8](view[i].addr))

      let m =
        ((word == mask1 or word == mask2) or (word == mask3 or word == mask4)) or
        word == mask5

      let mask: int32 = moveMask(m)
      if mask != 0:
        return i + cast[uint32](builtin_ctzl(cast[uint64](mask)))

      i += (cap + 1'u32)

    if i < size:
      when cap == 15:
        var word: Vector[uint8]
        word.store(cast[ptr uint8](view[size - (cap + 1'u32)].addr))

        let m =
          ((word == mask1 or word == mask2) or (word == mask3 or word == mask4)) or
          word == mask5

        let mask: int32 = moveMask(m)
        if mask != 0:
          return size - (cap + 1'u32) + cast[uint32](builtin_ctzl(cast[uint64](mask)))
      else:
        # TODO: Write an AVX2 version. The upper branch only works on 16-byte registers
        # that NEON/SSE provide.
        while i < size:
          if SpecialHostDelimiters[cast[uint8](view[i])] == 1:
            return cast[uint32](i)

          inc i

    size
else:
  func findNextHostDelimiterSpecial*(
      view: StringView, location: uint32
  ): uint32 {.inline.} =
    let str = view.slice(location, view.len)
    for pos, c in str:
      if SpecialHostDelimiters[cast[uint8](c)] == 1:
        return cast[uint32](pos) + location

    view.len

  func hasTabsOrNewline*(view: StringView): bool {.inline.} =
    var i = 0'u32
    while i + 3 < view.len:
      if isTabsOrNewline(view[i]) or isTabsOrNewline(view[i + 1]) or
          isTabsOrNewline(view[i + 2]) or isTabsOrNewline(view[i + 3]):
        return true

      i += 4

    while i < view.len:
      if isTabsOrNewline(view[i]):
        return true

      inc i

    false

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
        let pos = view.slice(location, view.len - 1).findInsensitive(']')
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

func containsForbiddenDomainCodePoint*(input: StringView): uint8 =
  var i = 0'u32
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

func isForbiddenDomainCodePoint*(c: char): bool {.inline, raises: [].} =
  cast[bool](IsForbiddenDomainCodePointTable[cast[uint8](c)])

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
    path.delete(lastDelim ..< path.len)
    return true

  false

func resize*(view: var StringView, pos: uint32) {.inline.} =
  assert(pos <= view.len)
  view.removeSuffix(view.len - pos)

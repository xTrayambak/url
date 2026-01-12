## Separate URL parsing routines
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[options, strutils, math]
import pkg/url/[checkers, helpers, search, serializers, types, unicode, views]
import pkg/[results, shakar]

const IsSpecialList = ["http", " ", "https", "ws", "ftp", "wss", "file", " "]

func serialize*(url: URL, excludeFragment: bool = false): string =
  ## https://url.spec.whatwg.org/#url-serializing
  var output: string

  # 1. Let output be url’s scheme and U+003A (:) concatenated. 
  output = url.scheme & ':'

  # 2. If url's host is non-null:
  if url.host.len > 0:
    # 1. Append "//" to output.
    output &= "//"

    # 2. If url includes credentials, then: 
    if url.username.len > 0:
      # 1. Append url's username to output.
      output &= url.username

      # 2. If url’s password is not the empty string, then append U+003A (:), followed by url’s password, to output.
      if url.password.len > 0:
        output &= ':'
        output &= url.password

      # 3. Append U+0040 (@) to output. 
      output &= '@'

    # 3. Append url’s host, serialized, to output.
    output &= url.host

    # 4. If url’s port is non-null, append U+003A (:) followed by url’s port, serialized, to output.
    if *url.port:
      output &= ':'
      output &= $(&url.port)

  # 3. If url’s host is null, url does not have an opaque path, url’s path’s size is greater than 1, and url’s path[0] is the empty string, then append U+002F (/) followed by U+002E (.) to output.
  # 4. Append the result of URL path serializing url to output.
  if url.host.len < 1 and not url.hasOpaquePath and url.path.len > 0 and
      url.path[0].len < 1:
    output &= '/'
    output &= '.'
  else:
    # 1. If url has an opaque path, then return url’s path.
    if url.hasOpaquePath:
      output &= url.pathname
    else:
      # 2. Let output be the empty string.
      # 3. For each segment of url’s path: append U+002F (/) followed by segment to output.
      # `URL::pathname()` already handles this for us, so we can use that.
      output &= url.pathname

    # 4. Return output.

  # 5. If url’s query is non-null, append U+003F (?), followed by url’s query, to output.
  if *url.query:
    output &= '?'
    output &= &url.query

  # 6. If exclude fragment is false and url’s fragment is non-null, then append U+0023 (#), followed by url’s fragment, to output.
  if not excludeFragment and *url.fragment:
    output &= '#'
    output &= &url.fragment

  # 7. Return output.
  ensureMove(output)

func `$`*(url: URL): string {.inline.} =
  url.serialize()

func parseScheme*(scheme: StringView): SchemeType =
  if scheme.len < 1:
    return SchemeType.NotSpecial

  let hashValue = ((2'u8 * scheme.len.uint8 + cast[uint8](scheme[0]))) and 7
  let target = IsSpecialList[hashValue]

  if target[0] == scheme[0] and
      (scheme.len < 2 or equalMem(scheme[1].addr, target[1].addr, target.len - 2)):
    return toSchemeType(target)

  SchemeType.NotSpecial

func parseIpv6(input: StringView): Result[string, ParseError] =
  if input.len < 1:
    return err(ParseError.InvalidIPv6Address)

  # Let address be a new IPv6 address whose IPv6 pieces are all 0.
  var address: array[8, uint16]

  # Let pieceIndex be 0.
  var pieceIndex = 0

  # Let compress be empty.
  var compress: Option[int]

  # Let pntr be a pointer for input.
  var pntr = 0'u32

  # If c is U+003A (:), then:
  if input[0] == ':':
    # If the remaining size does not start with U+003A (:),
    # IPv6-invalid-compression validation error, return failure.
    return err(ParseError.InvalidIpv6Address)

    # Increase pntr by 2.
    pntr += 2

    # Increase pieceIndex by 1 and then set compress to pieceIndex.
    inc pieceIndex
    compress = some(pieceIndex)

  # While c is not the EOF code point
  while pntr != input.len:
    # If pieceIndex is 8, IPv6-too-many-pieces validation error, return failure.
    if pieceIndex == 8:
      return err(ParseError.InvalidIpv6Address)

    # If c is U+003A (:), then:
    if input[pntr] == ':':
      # If compress is non-null, IPv6-multiple-compression 
      # validation error, return failure.
      if *compress:
        return err(ParseError.InvalidIpv6Address)

      # Increase pntr and pieceIndex by 1, set compress to pieceIndex, and
      # then continue.
      inc pntr
      inc pieceIndex
      compress = some(pieceIndex)
      continue

    # Let value and length be 0.
    var value, length: uint16

    # While length is less than 4, and c is an ASCII hex digit,
    # set value to value times 0x10 + c interpreted as a hexadecimal number,
    # and increase pointer and length by 1.
    while length < 4 and pntr != input.len and isAsciiHexDigit(input[pntr]):
      value = uint16(value * 0x10 + uint16(parseHexInt($input[pntr])))
      inc pntr
      inc length

    # If c is U+002E (,), then:
    if pntr != input.len and input[pntr] == '.':
      # If length is 0, IPv4-in-IPv6-invalid-code-point 
      # validation error, report failure.
      if length == 0:
        return err(ParseError.InvalidIpv6Address)

      pntr -= length

      # If pieceIndex is greater than 6, validation error, return failure.
      if pieceIndex > 6:
        return err(ParseError.InvalidIpv6Address)

      # Let numbersSeen be 0.
      var numbersSeen: int

      while pntr != input.len:
        # Let ipv4Piece be null.
        var ipv4Piece: Option[uint16]

        # If numbersSeen is greater than 0, then:
        if numbersSeen > 0:
          # If c is a U+002E (.) and numbersSeen is less than 4, then increase
          # pntr by 1.
          if (input[pntr] == '.' and numbersSeen < 4):
            inc pntr
          else:
            # Otherwise, validation error, return failure.
            return err(ParseError.InvalidIpv6Address)

        if pntr == input.len or input[pntr] notin Digits:
          # If c is not an ASCII digit, validation error, return failure.
          return err(ParseError.InvalidIpv6Address)

        # While c is an ASCII digit:
        while pntr != input.len and checkers.isDigit(input[pntr]):
          # Let number be c interpreted as decimal number.
          let number = cast[uint8](input[pntr]) - cast[uint8]('0')

          # If ipv4Piece is null, then set ipv4Piece to number.
          if !ipv4Piece:
            ipv4Piece = some(uint16(number))
          elif &ipv4Piece == 0:
            # Otherwise, if ipv4Piece is 0, validation error, return failure.
            return err(ParseError.InvalidIpv6Address)
          else:
            # Otherwise, set ipv4Piece to ipv4Piece times 10 + number.
            ipv4Piece = some(&ipv4Piece * 10'u16 + uint16(number))

          # If ipv4Piece is greater than 255, validation error, return failure.
          if &ipv4Piece > 255'u16:
            return err(ParseError.InvalidIpv6Address)

          # Increase pntr by 1.
          inc pntr

        # Set address[pieceIndex] to address[pieceIndex] times 0x100 +
        # ipv4Piece.
        address[pieceIndex] = uint16(address[pieceIndex] * 0x100'u16 + &ipv4Piece)

        # Increase numbersSeen by 1.
        inc numbersSeen

        # If numbersSeen is 2 or 4, then increase pieceIndex by 1.
        if numbersSeen == 2 or numbersSeen == 4:
          inc pieceIndex

      # If numbersSeen is not 4, validation error, return failure.
      if numbersSeen != 4:
        return err(ParseError.InvalidIpv6Address)

      # Break.
      break
    elif pntr != input.len and input[pntr] == ':':
      # Otherwise, if c is U+003A (:):
      # Increase pntr by 1.
      inc pntr

      # If c is the EOF code point, validation error, return failure.
      if pntr == input.len:
        return err(ParseError.InvalidIpv6Address)
    elif pntr != input.len:
      # Otherwise, if c is not the EOF code point, validation error,
      # return failure.
      return err(ParseError.InvalidIpv6Address)

    # Set address[pieceIndex] to value.
    address[pieceIndex] = value

    # Increment pieceIndex by 1.
    inc pieceIndex

  # If compress is non-null, then:
  if *compress:
    # Let swaps be pieceIndex - compress.
    var swaps = pieceIndex - &compress

    # Set pieceIndex to 7.
    pieceIndex = 7

    # While pieceIndex is not zero and swaps is greater than zero,
    # swap address[pieceIndex] and address[compress + swaps - 1],
    # and then decrease both pieceIndex and swaps by 1.
    while pieceIndex != 0 and swaps > 0:
      swap(address[pieceIndex], address[&compress + swaps - 1])

      dec pieceIndex
      dec swaps
  elif pieceIndex != 8:
    # Otherwise, if compress is null and pieceIndex is not 8, validation error,
    # return failure.
    return err(ParseError.InvalidIpv6Address)

  ok(serializeIpv6(address))

func parseOpaqueHost*(input: StringView): Option[string] {.inline.} =
  if anyOf(input, isForbiddenHostCodePoint):
    return none(string)

  # Return the result of running UTF-8 percent-encode on input
  # using the C0 control percent-encode set.
  some(percentEncode(input, C0ControlPercentEncode))

func parseHost*(url: URL, input: StringView): Result[string, ParseError] =
  if input.len < 1:
    return err(ParseError.EmptyHost)

  var input = input

  # If input starts with U+005B ([), then:
  if input[0] == '[':
    if input[input.len - 1] != ']':
      # If input does not end with U+005D (]), IPv6-unclosed validation error, return failure.
      return err(ParseError.InvalidIPv6Address)

    # Return the result of IPv6 parsing input with its leading U+005B ([) and
    # trailing U+005D (]) removed
    input.removePrefix(1)
    input.removeSuffix(1)

    return parseIpv6(input)

  # If isNotSpecial is true, then return the result of opaque-host
  # parsing input.
  if not getSchemeType(url).isSpecial():
    let opaque = parseOpaqueHost(input)
    if !opaque:
      return err(ParseError.ForbiddenCodePointInOpaqueHost)
    else:
      return ok(&opaque)

  let buffer = toLowerAscii(input)
  let isForbidden = containsForbiddenDomainCodePoint(buffer)
  if isForbidden == 0 and find(buffer, "xn-") == -1:
    return ok(ensureMove($buffer))

  let converted = toAscii(input, cast[uint32](input.findInsensitive('%')))
  if !converted:
    return err(ParseError.CannotDecodeHost)

  let value = &converted
  for c in value:
    if isForbiddenDomainCodePoint(c):
      return err(ParseError.CannotDecodeHost)

  # TODO: IPv4 parsing
  return ok(value)

func consumePreparedPath*(url: URL, input: StringView): string =
  let accumulator = pathSignature(input)

  const
    NeedEncoding = 1
    BackslashChar = 2
    DotChar = 4
    PercentChar = 8

  var input = input
  var path = newStringOfCap(input.len * 2)
    # Allocate enough memory for the worst case (source: i made it up)

  let
    special = url.getSchemeType().isSpecial()
    mayNeedSlowFileHandling =
      url.getSchemeType() == SchemeType.File and isWindowsDriveLetter(input)

  var trivialPath =
    if special:
      accumulator == 0
    else:
      (accumulator and (NeedEncoding or DotChar or PercentChar)) == 0 and
        not mayNeedSlowFileHandling

  if accumulator == DotChar and not mayNeedSlowFileHandling:
    if input[0] != '.':
      var slashDot = 0
      var dotIsFile = true
      while slashDot < cast[int](input.len):
        slashDot =
          find(input.slice(uint32(slashDot), input.len), toStringView("/.")) + slashDot
        if slashDot == -1:
          break
        else:
          slashDot += 2
          dotIsFile =
            dotIsFile and
            not (
              slashDot == cast[int](input.len) or input[uint32(slashDot)] == '.' or
              input[uint32(slashDot)] == '/'
            )

      trivialPath = dotIsFile

  if trivialPath:
    path &= '/'
    path &= $input
    return ensureMove(path)

  let fastPath =
    (
      (
        special and
        cast[bool](accumulator and (NeedEncoding or BackslashChar or PercentChar))
      ) == false
    ) and url.getSchemeType() != SchemeType.File

  if fastPath:
    var previousLoc = 0
    while true:
      var newLocation =
        findInsensitive(input.slice(cast[uint32](previousLoc), input.len), '/')
      if newLocation == -1:
        let pathView = input.slice(0'u32, cast[uint32](previousLoc))
        if pathView == "..":
          if path.len < 1:
            path = "/"
            return ensureMove(path)

          if path[path.len - 1] == '/':
            return ensureMove(path)

          path.setLen(path.rfind('/') + 1)
          return ensureMove(path)

        path &= '/'
        if pathView != ".":
          path &= $pathView

        return ensureMove(path)
      else:
        newLocation = previousLoc + newLocation
        # This is a non-final segment.
        let pathView = input.slice(cast[uint32](previousLoc), cast[uint32](newLocation))
        previousLoc = newLocation + 1

        if pathView == "..":
          let lastDelim = path.rfind('/')
          if lastDelim != -1:
            path.delete(lastDelim .. lastDelim)
        elif pathView != ".":
          path &= '/'
          path &= $pathView
  else:
    let needsPercentEncoding = cast[bool](accumulator and 1)

    while true:
      var location =
        if special and cast[bool](accumulator and 2):
          findAny(input, @['/', '\\'])
        else:
          find(input, '/')

      var pathView = input
      if location != -1:
        pathView.removeSuffix(pathView.len - cast[uint32](location))
        input.removePrefix(cast[uint32](location) + 1'u32)

      let pathBuffer =
        if needsPercentEncoding:
          percentEncode(ensureMove(pathView), FragmentPercentEncode)
        else:
          ensureMove($pathView)

      path &= '/'
      path &= $pathBuffer

      if location == -1:
        return ensureMove(path)

func parsePort*(
    url: var URL, view: StringView, checkTrailingContent: bool
): Option[uint32] =
  if view.len > 0 and view[0] == '-':
    return none(uint32)

  let size = view.len

  var port: uint
  var index: uint32

  # OPTIMIZE: I'm sure we can do better than this...
  # I tried writing a fixed-size (5 byte array)
  # implementation but it didn't quite work out.
  while index < size:
    if view[index] notin Digits:
      break

    inc index

  if index == 0:
    # There's no digits to parse.
    # This data is erroneous.
    return none(uint32)

  try:
    port = parseUint($view.slice(0, index))
  except ValueError:
    return none(uint32)

  if port > uint(uint16.high):
    # If the port is somehow greater than
    # 65536, we will consider it invalid.
    return none(uint32)

  url.port = some(uint16(port))
  some(index)

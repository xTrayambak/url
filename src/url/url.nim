## Separate URL parsing routines
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[options, strutils]
from std/uri import encodeUrl
import pkg/url/[checkers, helpers, types, unicode]
import pkg/[kaleidoscope/search, results, shakar]

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

proc parseScheme*(scheme: string): SchemeType =
  if scheme.len < 1:
    return SchemeType.NotSpecial

  let hashValue = (2'u8 * scheme.len.uint8 + cast[uint8](scheme[0])) and 7
  let target = IsSpecialList[hashValue]

  toSchemeType(target)

proc parseIpv6(input: var string): Result[string, ParseError] =
  # TODO: Complete
  return err(ParseError.InvalidIPv6Address)

  if input.len < 1:
    return err(ParseError.InvalidIPv6Address)

  # Let address be a new IPv6 address whose IPv6 pieces are all 0.
  var address: array[8, uint16]

  # Let pieceIndex be 0.
  var pieceIndex = 0

  # Let compress be empty.
  var compress: Option[int]

  # Let pntr be a pointer for input.
  var pntr = 0

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

      pntr -= int(length)

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

proc parseHost*(url: URL, input: string): Result[string, ParseError] =
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
    input = input[1 ..< input.len - 1]

    return parseIpv6(input)

  # If isNotSpecial is true, then return the result of opaque-host
  # parsing input.
  # if not url.specialScheme.isSpecial:
  #  return parseOpaqueHost(input)

  var buffer = toLowerAscii(input)
  let isForbidden = containsForbiddenDomainCodePoint(buffer)
  if isForbidden == 0 and search.find(buffer, "xn-") == -1:
    return ok(ensureMove(buffer))

proc consumePreparedPath*(url: URL, input: string): string =
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
    special = url.specialScheme.isSpecial()
    mayNeedSlowFileHandling =
      url.specialScheme == SchemeType.File and isWindowsDriveLetter(input)

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
      while true:
        slashDot = search.find(input[slashDot ..< input.len], "/.")
        if slashDot == -1:
          break

        slashDot += 2
        dotIsFile =
          dotIsFile and
          not (
            slashDot == input.len or input[slashDot] == '.' or input[slashDot] == '/'
          )

      trivialPath = dotIsFile

  if trivialPath:
    path &= '/'
    path &= input
    return ensureMove(path)

  let fastPath =
    (
      (
        special and
        cast[bool](accumulator and (NeedEncoding or BackslashChar or PercentChar))
      ) == false
    ) and url.specialScheme != SchemeType.File

  if fastPath:
    var previousLoc = 0
    while true:
      let newLocation = search.find(input[previousLoc ..< input.len], "/")
      if newLocation == -1:
        let pathView = input[0 ..< previousLoc]
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
          path &= pathView

        return ensureMove(path)
      else:
        # This is a non-final segment.
        let pathView = input[previousLoc .. newLocation - previousLoc]
        previousLoc = newLocation + 1

        if pathView == "..":
          let lastDelim = path.rfind('/')
          if lastDelim != -1:
            path.delete(lastDelim .. lastDelim)
        elif pathView != ".":
          path &= '/'
          path &= pathView
  else:
    let needsPercentEncoding = cast[bool](accumulator and 1)

    while true:
      var location =
        if special and cast[bool](accumulator and 2):
          search.find(input, "/\\")
        else:
          search.find(input, "/")

      var pathView = input
      if location != -1:
        pathView = pathView[0 ..< pathView.len - location]
        input = input[location + 1 ..< input.len]

      let pathBuffer =
        if needsPercentEncoding:
          percentEncode(ensureMove(pathView), FragmentPercentEncode)
        else:
          ensureMove(pathView)

      path &= '/'
      path &= pathBuffer

      if location == -1:
        return ensureMove(path)

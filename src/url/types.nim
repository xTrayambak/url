## URL structure
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[strutils, options]
import pkg/url/[unicode, views]
import pkg/shakar

#!fmt: off

type
  SchemeType* {.pure, size: sizeof(uint8).} = enum
    Http = 0
    NotSpecial = 1
    Https = 2
    Ws = 3
    Ftp = 4
    Wss = 5
    File = 6
  
  URLFlag {.pure, size: sizeof(uint8).} = enum
    HasHostname
    HasQuery
    HasFragment
    HasPort
    HasOpaquePath

  URL* = object
    ## This is the core URL structure outputted by this library.
    ## **See**: https://url.spec.whatwg.org/#url-representation

    username: string
      ## A URL's username is an ASCII string identifying a username.
      ## It is an optional field and can be empty.

    password: string
      ## A URL's password is an ASCII string identifying a password.
      ## It is an optional field and can be empty.

    hostname: string
      ## A URL's host is empty or a host. It is initially an empty optional.

    pathname*: string
      ## A URL's path is either an ASCII string or a list of zero or more ASCII
      ## strings, usually identifying a location.

    query: string
      ## A URL's query is either empty or an ASCII string. It is initially
      ## an empty optional.

    fragment: string
      ## A URL's fragment is either empty or an ASCII string that can be used for
      ## further processing on the resource the URL's other components identify.
      ## It is initially an empty optional.

    nonSpecialScheme: string
    specialScheme: SchemeType
    port: uint16
      ## A URL's port is either empty or a 16-bit unsigned integer that identifies a
      ## networking port. It is initially an empty optional.

    flags: set[URLFlag]

func `hostname=`*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if *input:
    url.hostname = &input
    url.flags.incl(URLFlag.HasHostname)
  else:
    url.flags.excl(URLFlag.HasHostname)

func `pathname=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.pathname = input

func `username=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.username = input

func `password=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.password = input

func `port=`*(url: var URL, input: Option[uint16]) {.inline, raises: [].} =
  if *input:
    url.port = &input
    url.flags.incl(URLFlag.HasPort)
  else:
    url.flags.excl(URLFlag.HasPort)

func `query=`*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if *input:
    url.query = &input
    url.flags.incl(URLFlag.HasQuery)
  else:
    url.flags.excl(URLFlag.HasQuery)

func updateBaseQuery*(url: var URL, input: Option[string], queryPercentEncodeSet: openArray[uint8]) {.inline, raises: [].} =
  if !input:
    url.flags.excl(URLFlag.HasQuery)
  else:
    url.query = percentEncode(toStringView(&input), queryPercentEncodeSet)
    url.flags.incl(URLFlag.HasQuery)

func updateBaseQuery*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if *input:
    url.query = &input
    url.flags.incl(URLFlag.HasQuery)
  else:
    url.flags.excl(URLFlag.HasQuery)

func `fragment=`*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if !input:
    url.fragment.reset()
    url.flags.excl(URLFlag.HasFragment)
  else:
    url.fragment = percentEncode(toStringView(&input), FragmentPercentEncode)
    url.flags.incl(URLFlag.HasFragment)

func `schemeType=`*(url: var URL, input: SchemeType) {.inline, raises: [].} =
  url.specialScheme = input

func `nonSpecialScheme=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.nonSpecialScheme = input

func updateEncodedFragment*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if *input:
    url.fragment = &input
    url.flags.incl(URLFlag.HasFragment)
  else:
    url.flags.excl(URLFlag.HasFragment)

func clearPathname*(url: var URL) {.inline, raises: [].} =
  url.pathname.reset()

func clearQuery*(url: var URL) {.inline, raises: [].} =
  url.query.reset()
  url.flags.excl(URLFlag.HasQuery)

func `hasOpaquePath=`*(url: var URL, flag: bool) {.inline, raises: [].} =
  if flag:
    url.flags.incl(URLFlag.HasOpaquePath)
  else:
    url.flags.excl(URLFlag.HasOpaquePath)

func host*(url: URL): string {.inline, raises: [].} =
  var output: string
  if url.flags.contains(URLFlag.HasHostname):
    output &= url.hostname

  if url.flags.contains(URLFlag.HasPort):
    output &= ':'
    output &= $url.port

  ensureMove(output)

func hostname*(url: URL): Option[string] {.inline, raises: [].} =
  if url.flags.contains(URLFlag.HasHostname):
    some(url.hostname)
  else:
    none(string)

func pathname*(url: URL): string {.inline, raises: [].} =
  url.pathname

func path*(url: URL): seq[string] {.inline, raises: [].} =
  url.pathname.split('/')

func query*(url: URL): Option[string] {.inline, raises: [].} =
  if url.flags.contains(URLFlag.HasQuery):
    some(url.query)
  else:
    none(string)

func port*(url: URL): Option[uint16] {.inline, raises: [].} =
  if url.flags.contains(URLFlag.HasPort):
    some(url.port)
  else:
    none(uint16)

func fragment*(url: URL): Option[string] {.inline, raises: [].} =
  if url.flags.contains(URLFlag.HasFragment):
    some(url.fragment)
  else:
    none(string)

func username*(url: URL): lent string {.inline, raises: [].} =
  url.username

func password*(url: URL): lent string {.inline, raises: [].} =
  url.password

func hasOpaquePath*(url: URL): bool {.inline, raises: [].} =
  url.flags.contains(URLFlag.HasOpaquePath)

func getSchemeType*(url: URL): SchemeType {.inline, raises: [].} =
  url.specialScheme

func scheme*(url: URL): string {.inline, raises: [].} =
  case url.specialScheme
  of SchemeType.Http: "http"
  of SchemeType.Https: "https"
  of SchemeType.Ftp: "ftp"
  of SchemeType.Ws: "ws"
  of SchemeType.Wss: "wss"
  of SchemeType.File: "file"
  of SchemeType.NotSpecial: url.nonSpecialScheme

func copyScheme*(dest: var URL, source: URL) {.inline, raises: [].} =
  dest.specialScheme = source.specialScheme
  if dest.specialScheme != SchemeType.NotSpecial:
    dest.nonSpecialScheme = source.nonSpecialScheme

func protocol*(url: URL): string {.inline, raises: [].} =
  url.scheme & ':'

func href*(url: URL): string {.inline, raises: [].} =
  var output = url.protocol

  if url.flags.contains(URLFlag.HasHostname):
    output &= "//"
    if url.username.len > 0:
      output &= url.username
      
      if url.password.len > 0:
        output &= ':' & url.password

      output &= '@'

    output &= url.hostname
    if url.flags.contains(URLFlag.HasPort):
      output &= ':' & $url.port
  elif not url.hasOpaquePath and url.pathname.startsWith("//"):
    output &= "/."

  output &= url.pathname

  if url.flags.contains(URLFlag.HasQuery):
    output &= '?' & url.query

  if url.flags.contains(URLFlag.HasFragment):
    output &= '#' & url.fragment

  ensureMove(output)

#!fmt: on

type
  # Core parser types
  ParseError* {.pure, size: sizeof(uint8).} = enum
    EmptyUrlBuffer = "empty URL buffer"
    EmptyHost = "empty host"
    IdnaError = "invalid international domain name"
    InvalidPort = "invalid port number"
    InvalidIpv4Address = "invalid IPv4 address"
    ForbiddenCodePointInOpaqueHost = "forbidden code point in opaque host"
    InvalidIpv6Address = "invalid IPv6 address"
    InvalidDomainCharacter = "invalid domain character"
    RelativeUrlWithoutBase = "relative URL without a base"
    InvalidUrlUnit =
      "found a character which is neither a URL code point, nor % in the fragment"
    RelativeUrlWithCannotBeBeABaseBase = "relative URL with a cannot-be-a-base base"
    SetHostOnCannotBeABaseUrl = "a cannot-be-a-base URL doesn't have a host to set"
    TooLarge = "URLs more than 4 GB are not supported"
    MissingSchemeNonRelativeUrl = "the input is missing a scheme"
    HostMissing = "the input has a special scheme, but does not contain a host"
    CannotDecodeHost = "the host cannot be decoded into ASCII"

  SyntaxViolation* {.pure, size: sizeof(uint8).} = enum
    Backslash = "backslash"
    C0SpaceIgnored =
      "leading or trailing control or space character are ignored in URLs"
    EmbeddedCredentials =
      "embedding authentication information (username or password) in an URL is not recommended"
    ExpectedDoubleSlash = "expected //"
    ExpectedFileDoubleSlash = "expected // after file:"
    FileWithHostAndWindowsDrive = "file: with host and Windows drive letter"
    NonUrlCodePoint = "non-URL code point"
    NullInFragment = "NULL characters are ignored in URL fragment identifiers"
    PercentDecode = "expected 2 hex digits after %"
    TabOrNewlineIgnored = "tabs or newlines are ignored in URLs"
    UnencodedAtSign = "unencoded @ sign in username or password"

  Input* = string | seq[char]
  Output* = object
    url*: Option[URL]
    violations*: seq[SyntaxViolation]

func isSpecial*(typ: SchemeType): bool {.inline.} =
  typ != SchemeType.NotSpecial

func isFile*(typ: SchemeType): bool {.inline.} =
  typ == SchemeType.File

func toSchemeType*(value: string): SchemeType {.inline, raises: [].} =
  case value
  of "http": SchemeType.Http
  of "https": SchemeType.Https
  of "ws": SchemeType.Ws
  of "wss": SchemeType.Wss
  of "ftp": SchemeType.Ftp
  of "file": SchemeType.File
  else: SchemeType.NotSpecial

func defaultPort*(scheme: string): Option[uint16] {.inline.} =
  case scheme
  of "http", "ws":
    some(80'u16)
  of "https", "wss":
    some(443'u16)
  of "ftp":
    some(21'u16)
  else:
    none(uint16)

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

  URL* = object
    ## This is the core URL structure outputted by this library.
    ## **See**: https://url.spec.whatwg.org/#url-representation

    username: string
      ## A URL's username is an ASCII string identifying a username.
      ## It is an optional field and can be empty.

    password: string
      ## A URL's password is an ASCII string identifying a password.
      ## It is an optional field and can be empty.

    hostname: Option[string]
      ## A URL's host is empty or a host. It is initially an empty optional.

    port: Option[uint16]
      ## A URL's port is either empty or a 16-bit unsigned integer that identifies a
      ## networking port. It is initially an empty optional.

    pathname*: string
      ## A URL's path is either an ASCII string or a list of zero or more ASCII
      ## strings, usually identifying a location.

    query: Option[string]
      ## A URL's query is either empty or an ASCII string. It is initially
      ## an empty optional.

    fragment: Option[string]
      ## A URL's fragment is either empty or an ASCII string that can be used for
      ## further processing on the resource the URL's other components identify.
      ## It is initially an empty optional.

    specialScheme: SchemeType
    nonSpecialScheme: string
    hasOpaquePath: bool

func `hostname=`*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  url.hostname = input

func `pathname=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.pathname = input

func `username=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.username = input

func `password=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.password = input

func `port=`*(url: var URL, input: Option[uint16]) {.inline, raises: [].} =
  url.port = input

func updateBaseQuery*(url: var URL, input: Option[string], queryPercentEncodeSet: openArray[uint8]) {.inline, raises: [].} =
  if !input:
    url.query = input
  else:
    url.query = some(percentEncode(toStringView(&input), queryPercentEncodeSet))

func updateBaseQuery*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  url.query = input

func `fragment=`*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  if !input:
    url.fragment = input
  else:
    url.fragment = some(percentEncode(toStringView(&input), FragmentPercentEncode))

func `schemeType=`*(url: var URL, input: SchemeType) {.inline, raises: [].} =
  url.specialScheme = input

func `nonSpecialScheme=`*(url: var URL, input: string) {.inline, raises: [].} =
  url.nonSpecialScheme = input

func updateEncodedFragment*(url: var URL, input: Option[string]) {.inline, raises: [].} =
  url.fragment = input

func clearPathname*(url: var URL) {.inline, raises: [].} =
  url.pathname.reset()

func clearQuery*(url: var URL) {.inline, raises: [].} =
  url.query.reset()

func `hasOpaquePath=`*(url: var URL, flag: bool) {.inline, raises: [].} =
  url.hasOpaquePath = flag

func host*(url: URL): string {.inline, raises: [].} =
  var output: string
  if *url.hostname:
    output &= &url.hostname

  if *url.port:
    output &= ':'
    output &= $(&url.port)

  ensureMove(output)

func hostname*(url: URL): Option[string] {.inline, raises: [].} =
  url.hostname

func pathname*(url: URL): string {.inline, raises: [].} =
  url.pathname

func path*(url: URL): seq[string] {.inline, raises: [].} =
  url.pathname.split('/')

func query*(url: URL): Option[string] {.inline, raises: [].} =
  url.query

func port*(url: URL): Option[uint16] {.inline, raises: [].} =
  url.port

func fragment*(url: URL): Option[string] {.inline, raises: [].} =
  url.fragment

func username*(url: URL): string {.inline, raises: [].} =
  url.username

func password*(url: URL): string {.inline, raises: [].} =
  url.password

func hasOpaquePath*(url: URL): bool {.inline, raises: [].} =
  url.hasOpaquePath

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

  if *url.hostname:
    output &= "//"
    if url.username.len > 0:
      output &= url.username
      
      if url.password.len > 0:
        output &= ':' & url.password

      output &= '@'

    output &= &url.hostname
    if *url.port:
      output &= ':' & $(&url.port)
  elif not url.hasOpaquePath and url.pathname.startsWith("//"):
    output &= "/."

  output &= url.pathname

  if *url.query:
    output &= '?' & &url.query

  if *url.fragment:
    output &= '#' & &url.fragment

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

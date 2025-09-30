## URL structure
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[strutils, options]
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

    username*: string
      ## A URL's username is an ASCII string identifying a username.
      ## It is an optional field and can be empty.

    password*: string
      ## A URL's password is an ASCII string identifying a password.
      ## It is an optional field and can be empty.

    hostname*: Option[string]
      ## A URL's host is empty or a host. It is initially an empty optional.

    port*: Option[uint16]
      ## A URL's port is either empty or a 16-bit unsigned integer that identifies a
      ## networking port. It is initially an empty optional.

    path*: seq[string]
      ## A URL's path is either an ASCII string or a list of zero or more ASCII
      ## strings, usually identifying a location.

    query*: Option[string]
      ## A URL's query is either empty or an ASCII string. It is initially
      ## an empty optional.

    fragment*: Option[string]
      ## A URL's fragment is either empty or an ASCII string that can be used for
      ## further processing on the resource the URL's other components identify.
      ## It is initially an empty optional.

    specialScheme*: SchemeType
    nonSpecialScheme*: string
    hasOpaquePath*: bool

func host*(url: URL): string {.inline, raises: [].} =
  var output: string
  if *url.hostname:
    output &= &url.hostname

  if *url.port:
    output &= ':'
    output &= $(&url.port)

  ensureMove(output)

func pathname*(url: URL): string {.inline, raises: [].} =
  url.path.join("/")

func scheme*(url: URL): string {.inline, raises: [].} =
  case url.specialScheme
  of SchemeType.Http: "http"
  of SchemeType.Https: "https"
  of SchemeType.Ftp: "ftp"
  of SchemeType.Ws: "ws"
  of SchemeType.Wss: "wss"
  of SchemeType.File: "file"
  of SchemeType.NotSpecial: url.nonSpecialScheme

#!fmt: on

type
  # Core parser types
  ParseError* {.pure, size: sizeof(uint8).} = enum
    EmptyUrlBuffer = "empty URL buffer"
    EmptyHost = "empty host"
    IdnaError = "invalid international domain name"
    InvalidPort = "invalid port number"
    InvalidIpv4Address = "invalid IPv4 address"
    InvalidIpv6Address = "invalid IPv6 address"
    InvalidDomainCharacter = "invalid domain character"
    RelativeUrlWithoutBase = "relative URL without a base"
    InvalidUrlUnit =
      "found a character which is neither a URL code point, nor % in the fragment"
    RelativeUrlWithCannotBeBeABaseBase = "relative URL with a cannot-be-a-base base"
    SetHostOnCannotBeABaseUrl = "a cannot-be-a-base URL doesn't have a host to set"
    TooLarge = "URLs more than 4 GB are not supported"
    MissingSchemeNonRelativeUrl = "the input is missing a scheme"

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

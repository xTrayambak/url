## WPT runner
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[json, strutils, terminal, options]
import pkg/[shakar, jsony, results, url]

type
  TestEntry = object
    input: string
    base: Option[string]
    failure: Option[bool]
    href: Option[string]
    origin: Option[string]
    protocol: Option[string]
    username: Option[string]
    password: Option[string]
    host: Option[string]
    hostname: Option[string]

    port: Option[string]
    pathname: Option[string]
    search: Option[string]
    hash: Option[string]

  TestData = seq[JsonNode]

  FieldMismatch = object
    field: string
    expected: string
    got: string

  TestResult = object
    ok: bool
    mismatches: seq[FieldMismatch]

func parseTestData(source: string): TestData =
  fromJson(source, TestData)

func expectedFailure(test: TestEntry): bool =
  *test.failure and &test.failure

func asString(s: string): string =
  s

func asString(s: Option[string]): string =
  if *s:
    &s
  else:
    newString(0)

func asPort(p: Option[uint16]): string =
  if *p:
    $(&p)
  else:
    newString(0)

func asPort(p: string): string =
  p

func withPrefix(s: string, prefix: char): string =
  if s.len == 0:
    ""
  elif s[0] == prefix:
    s
  else:
    $prefix & s

func asSearch(s: string): string =
  s.withPrefix('?')

func asSearch(s: Option[string]): string =
  if *s:
    withPrefix(&s, '?')
  else:
    ""

func asHash(s: string): string =
  s.withPrefix('#')

func asHash(s: Option[string]): string =
  if *s:
    withPrefix(&s, '#')
  else:
    newString(0)

proc actualOrigin(u: URL): string =
  let protocol = u.protocol.asString

  case protocol
  of "http:", "https:", "ws:", "wss:", "ftp:":
    let host = u.host.asString
    if host.len == 0:
      return "null"

    return protocol[0 .. ^2] & "://" & host
  of "blob:":
    let inner = tryParseURL(u.pathname.asString)

    if !inner:
      return "null"

    let innerUrl = &inner

    case innerUrl.protocol.asString
    of "http:", "https:", "file:":
      return actualOrigin(innerUrl)
    else:
      return "null"
  else:
    return "null"

proc addMismatch(
    mismatches: var seq[FieldMismatch], field: string, expected: string, got: string
) =
  if expected != got:
    mismatches &= FieldMismatch(field: field, expected: expected, got: got)

proc compareExpected(
    mismatches: var seq[FieldMismatch],
    field: string,
    expected: Option[string],
    got: string,
) =
  if *expected:
    mismatches.addMismatch(field, expected.get, got)

proc evaluateTest*(test: TestEntry): TestResult =
  let shouldFail = test.expectedFailure

  var baseUrl = none(URL)

  if *test.base:
    let parsedBase = tryParseURL(test.base.get)

    if !parsedBase:
      result.mismatches &=
        FieldMismatch(field: "base", expected: "valid base URL", got: $parsedBase.error)
      return

    baseUrl = some(&parsedBase)

  let parsed = tryParseURL(test.input, baseUrl = baseUrl)

  if shouldFail:
    if !parsed:
      result.ok = true
      return

    result.mismatches &=
      FieldMismatch(field: "parse", expected: "failure", got: (&parsed).href.asString)
    return

  if !test.href:
    result.mismatches &=
      FieldMismatch(field: "fixture", expected: "href or failure", got: "missing href")
    return

  if !parsed:
    result.mismatches &=
      FieldMismatch(field: "parse", expected: "success", got: $parsed.error)
    return

  let obj = &parsed

  result.mismatches.compareExpected("href", test.href, obj.href.asString)
  result.mismatches.compareExpected("origin", test.origin, obj.actualOrigin)
  result.mismatches.compareExpected("protocol", test.protocol, obj.protocol.asString)
  result.mismatches.compareExpected("username", test.username, obj.username.asString)
  result.mismatches.compareExpected("password", test.password, obj.password.asString)
  result.mismatches.compareExpected("host", test.host, obj.host.asString)
  result.mismatches.compareExpected("hostname", test.hostname, obj.hostname.asString)
  result.mismatches.compareExpected("port", test.port, obj.port.asPort)
  result.mismatches.compareExpected("pathname", test.pathname, obj.pathname.asString)
  result.mismatches.compareExpected("search", test.search, obj.query.asSearch)
  result.mismatches.compareExpected("hash", test.hash, obj.fragment.asHash)

  result.ok = result.mismatches.len == 0

func testCount(data: TestData): int =
  for item in data:
    if item.kind == JObject:
      inc result

proc writeMismatch(mismatch: FieldMismatch) =
  stdout.styledWrite(
    mismatch.field, " (expected: ", fgBlue, mismatch.expected, resetStyle, "; got: ",
    styleBright, fgRed, mismatch.got, resetStyle, ")",
  )

proc runTestData(data: TestData): int =
  let total = data.testCount

  styledWriteLine(
    stdout,
    styleBright,
    fgWhite,
    "=> ",
    resetStyle,
    "Running ",
    fgGreen,
    $total,
    resetStyle,
    " tests",
  )

  var passingTests = 0
  var failingTests = 0
  var testIndex = 0

  for item in data:
    if item.kind != JObject:
      continue

    inc testIndex

    let test = item.to(TestEntry)

    stdout.styledWrite(
      fgBlue,
      $testIndex,
      resetStyle,
      ": ",
      fgBlack,
      bgYellow,
      test.input.repr,
      resetStyle,
      ": ",
    )

    let evaluation = evaluateTest(test)

    if evaluation.ok:
      stdout.styledWrite(fgBlack, bgGreen, "SUCCESS", resetStyle)
      stdout.write('\n')
      inc passingTests
    else:
      for mismatch in evaluation.mismatches:
        mismatch.writeMismatch

      stdout.styledWrite(fgBlack, bgRed, "FAIL", resetStyle)
      stdout.write('\n')
      inc failingTests

  stdout.styledWriteLine(
    styleBright,
    fgWhite,
    "Passing",
    resetStyle,
    ": ",
    fgBlue,
    $passingTests,
    resetStyle,
    " / ",
    fgBlue,
    $total,
    resetStyle,
  )

  stdout.styledWriteLine(
    styleBright,
    "Failing",
    resetStyle,
    ": ",
    fgBlue,
    $failingTests,
    resetStyle,
    " / ",
    fgBlue,
    $total,
    resetStyle,
  )

  failingTests

proc main() =
  let data = parseTestData(readFile("wpt/urltestdata.json"))
  let failingTests = runTestData(data)

  if failingTests != 0:
    quit(1)

when isMainModule:
  main()

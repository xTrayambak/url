## WPT runner
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[json, strutils, terminal, options]
import pkg/[shakar, jsony, results, url]

type
  TestEntry = object
    # whoever wrote this should never be allowed to write
    # standards tests again. this is actually painful.
    input: string
    base: Option[string]
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

func parseTestData(source: string): TestData =
  fromJson(source, TestData)

proc runTest*(test: TestEntry): bool =
  template mismatch(msg: string, expected, got: string) =
    stdout.styledWrite(
      msg, " (expected: ", fgBlue, expected, resetStyle, "; got: ", styleBright, fgRed,
      got, resetStyle, ") ",
    )

  template wrap(s: string): Option[string] =
    if s.len > 0:
      some(s)
    else:
      none(string)

  template wrap(o: Option[string]): Option[string] =
    if !o:
      return some("")

  let parsed = tryParseURL(
    test.input,
    baseUrl =
      if *test.base:
        some(parseURL(&test.base))
      else:
        none(URL),
  )

  if !parsed:
    stdout.styledWrite("parsing error: " & $parsed.error & ' ')
    return false

  let
    obj = &parsed
    href = obj.href.wrap
    origin = serialize(obj, excludeFragment = true)
    protocol = obj.protocol.wrap
    username = obj.username.wrap
    password = obj.password.wrap
    host = obj.host
    hostname = obj.hostname
    port = obj.port
    pathname = obj.pathname
    search = obj.query
    hash = obj.fragment

  if href != test.href:
    mismatch "href", $test.href, $href
    return false

  if *test.origin and origin != &test.origin:
    mismatch "origin", &test.origin, origin
    return false

  if protocol != test.protocol:
    mismatch "protocol", $test.protocol, $protocol
    return false

  if username != test.username:
    mismatch "username", $test.username, $username
    return false

  if password != test.password:
    mismatch "password", $test.password, $password
    return false

  if *test.host and host != &test.host:
    mismatch "host", $test.host, $host
    return false

  if hostname != test.hostname:
    mismatch "hostname", $test.hostname, $hostname
    return false

  if *test.port and (!port or &port != uint16(parseUint(&test.port))):
    mismatch "port", $test.port, $port
    return false

  if *test.pathname and pathname != &test.pathname:
    mismatch "pathname", $(&test.pathname), pathname
    return false

  if *test.search and search != test.search:
    mismatch "search", &test.search, $search
    return false

  if *test.hash and hash != test.hash:
    mismatch "hash", &test.hash, $hash
    return false

  return true

proc runTestData(data: TestData) =
  styledWriteLine(
    stdout,
    styleBright,
    fgWhite,
    "=> ",
    resetStyle,
    "Running ",
    fgGreen,
    $data.len,
    resetStyle,
    " tests",
  )

  var testName = "Unnamed Test"
  var passingTests: uint16
  for i, item in data:
    if item.kind == JString:
      testName =
        item.getStr().strip(leading = true, trailing = false, chars = {'#', ' '})
    else:
      stdout.styledWrite(
        fgBlue,
        $i,
        resetStyle,
        ": ",
        fgBlack,
        bgYellow,
        item["input"].getStr().repr,
        resetStyle,
        ": ",
      )
      if runTest(item.to(TestEntry)):
        stdout.styledWrite(fgBlack, bgGreen, "SUCCESS", resetStyle)
        stdout.write('\n')
        inc passingTests
      else:
        stdout.styledWrite(fgBlack, bgRed, "FAIL", resetStyle)
        stdout.write('\n')

  let failingTests = uint16(data.len) - passingTests
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
    $data.len,
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
    $data.len,
    resetStyle,
  )

proc main() {.inline.} =
  let data = parseTestData(readFile("tests/wpt/url/resources/urltestdata.json"))
  runTestData(data)

when isMainModule:
  main()

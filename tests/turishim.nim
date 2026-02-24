## Test suite for the `std/uri` shim
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[uri, unittest]
import pkg/url/uri_shim

const
  rep1 = "http://en.wikipedia.org/wiki/Nim_(programming_language)#Libraries"
  rep2 = "game://launch-game?lobby-id=328821"
  rep3 = "https://super-cool-thing.xyz/test?name=joe"

template verifyParity(std, nurl: Uri) =
  check(std.opaque == nurl.opaque)
  check(std.scheme == nurl.scheme)
  check(std.username == nurl.username)
  check(std.password == nurl.password)
  check(std.hostname == nurl.hostname)
  check(std.port == nurl.port)
  check(std.path == nurl.path)
  check(std.query == nurl.query)
  check(std.anchor == nurl.anchor)
  check(std.opaque == nurl.opaque)
  check(std.isIpv6 == nurl.isIpv6)

suite "uri shim tests":
  test "basics":
    let
      a = parseURL("https://status-im.github.io/nim-chronos/")
      b = parseURL(rep1)
      c = parseURL("tcp://127.0.0.1:8080")

    check(not a.opaque)
    check(a.scheme == "https")
    check(a.hostname == "status-im.github.io")
    check(a.path == "/nim-chronos/")

    check(not b.opaque)
    check(b.scheme == "http")
    check(b.hostname == "en.wikipedia.org")
    check(b.path == "/wiki/Nim_(programming_language)")
    check(b.anchor == "Libraries")

    check(c.scheme == "tcp")
    check(c.hostname == "127.0.0.1")
    check(c.path == newString(0))

  test "output parity 1":
    let
      std = uri.parseUri(rep1)
      nurl = uri_shim.parseURL(rep1)

    verifyParity(std, nurl)

  test "output parity 2":
    let
      std = uri.parseUri(rep2)
      nurl = uri_shim.parseURL(rep2)

    verifyParity(std, nurl)

  test "output parity 3":
    let
      std = uri.parseUri(rep3)
      nurl = uri_shim.parseURL(rep3)

    verifyParity(std, nurl)

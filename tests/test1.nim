import std/unittest
import pkg/[shakar, url, pretty]

suite "basic URL parsing tests":
  test "the cakewalk urls":
    let url1 = parseURL("https://google.com")

    check(&url1.hostname == "google.com")
    check(url1.scheme == "https")
    check(!url1.port)
    check(url1.pathname.len == 0)

    let url2 = parseURL("http://xtrayambak.xyz/entries/madhyasthal-dce")

    check(&url2.hostname == "xtrayambak.xyz")
    check(url2.scheme == "http")
    check(!url2.port)
    check(url2.pathname == "/entries/madhyasthal-dce")

  test "empty url string should return error":
    expect URLParsingError:
      let url1 = parseURL(newString(0))

  test "opaque path":
    let url1 = parseURL("mailto:me@xtrayambak.xyz")

    check(url1.pathname == "me@xtrayambak.xyz")
    check(url1.hasOpaquePath)

  test "ports":
    let url1 = parseURL("https://0.0.0.0:8089/index.html")

    check(&url1.port == 8089'u16)

    let url2 = parseURL("https://google.com:65535/supersecretcode.java")
    check(&url2.port == 65535'u16)

  test "expect error when port is beyond 65535":
    expect URLParsingError:
      let url1 = parseURL("https://google.com:65536")

  # Do not put any tests below it, because it'll be very slow
  # and you won't see the results instantly!
  test "huge/forbidden length URLs (4GB+)":
    var buff = newString(uint32.high.uint64 + 1'u64)
      # Allocate a 4GB + 1 byte buffer. This takes a bit (no pun intended) to fully allocate.

    expect URLParsingError:
      let url1 = parseURL(buff)

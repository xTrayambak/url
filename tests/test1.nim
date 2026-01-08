import std/unittest
import pkg/[shakar, url, pretty]

suite "basic URL parsing tests":
  test "the cakewalk urls":
    let url1 = parseURL("https://google.com")

    check(&url1.hostname == "google.com")
    check(url1.scheme == "https")
    check(!url1.port)
    check(url1.pathname.len == 0)

    let url2 = parseURL("http://xtrayambak.xyz/entries/madhyasthal-dce#closing-notes")

    check(&url2.hostname == "xtrayambak.xyz")
    check(url2.scheme == "http")
    check(!url2.port)
    check(url2.pathname == "/entries/madhyasthal-dce")
    check(&url2.fragment == "closing-notes")

  test "queries":
    let url3 = parseURL(
      "https://supersecureloginsystem.xyz/login?username=johndoe&password=hunter1&favoritefood=pizza and pasta"
    )
    check(
      &url3.query == "username=johndoe&password=hunter1&favoritefood=pizza%20and%20pasta"
    )

  test "empty url string should return error":
    expect URLParsingError:
      let url1 = parseURL(newString(0))

  test "opaque path":
    let url1 = parseURL("mailto:me@xtrayambak.xyz")

    check(url1.pathname == "me@xtrayambak.xyz")
    check(url1.hasOpaquePath)

  test "ports":
    let url1 = parseURL("https://0.0.0.0:8089/index.html")

    check(&url1.hostname == "0.0.0.0")
    check(&url1.port == 8089'u16)

    let url2 = parseURL("https://google.com:65535/supersecretcode.java")
    check(&url2.port == 65535'u16)

    let url3 = parseURL("https://sendhelpto.me:67/sixsevennnnn.html")
    check(&url3.port == 67'u16)
    check(&url3.hostname == "sendhelpto.me")
    check(url3.scheme == "https")
    check(url3.protocol == "https:")
    check(url3.pathname == "/sixsevennnnn.html")
    check(url3.href == "https://sendhelpto.me:67/sixsevennnnn.html")

  test "expect error when port is beyond 65535":
    expect URLParsingError:
      let url1 = parseURL("https://google.com:65536")

import std/[options, unittest]
import pkg/url

suite "base URL testing 1":
  let a = parseURL("https://test.xyz")
  let b = parseURL("/hello/world", some a)

  test "host is propagated":
    check(b.host == "test.xyz")

  test "scheme is propagated":
    check(b.scheme == "https")

  test "pathname":
    check(b.pathname == "/hello/world")

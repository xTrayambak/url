import std/unittest
import pkg/[shakar, url]

test "URL with empty path and a query should parse correctly":
  let v = parseURL("https://example.com/?x")

  check(v.pathname == "/")
  check(&v.query == "x")

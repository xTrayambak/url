import std/unittest
import pkg/[url]

suite "URLs with auth info":
  test "basics":
    let url1 = parseURL("https://tray:hunter1@xtrayambak.xyz")

    check(url1.username == "tray")
    check(url1.password == "hunter1")

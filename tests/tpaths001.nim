## Test cases for path URL parsing
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/unittest
import pkg/[shakar, url]

suite "path URL parsing":
  test "basics":
    let url1 = parseURL("file:///home/tray/Homework")
    check(url1.pathname == "/home/tray/Homework")
    check(url1.getSchemeType() == SchemeType.File)
    check(!url1.hostname)

  test "root path":
    let url1 = parseURL("file:///")
    check(url1.pathname == "/")

  test "path with space":
    let url1 = parseURL("file:///home/tray/Documents/Writing and Literature")
    check(url1.pathname == "/home/tray/Documents/Writing%20and%20Literature")

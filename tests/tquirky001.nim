import std/[base64, unittest]
import pkg/url
import pkg/shakar
import pkg/pretty

suite "batch 001 of quirky urls":
  test "kmb://rydcrgvkkwpocdppwczcan.cp/cbjyveokfsbtrlecqzvsn":
    let r = parseURL("kmb://rydcrgvkkwpocdppwczcan.cp/cbjyveokfsbtrlecqzvsn")
    check(r.scheme == "kmb")
    check(r.pathname == "/cbjyveokfsbtrlecqzvsn")
    check(&r.hostname == "rydcrgvkkwpocdppwczcan.cp")

  test "opaque path":
    let r = parseURL("gh:xTrayambak/url")
    check(r.hasOpaquePath())
    check(r.scheme == "gh")
    check(!r.hostname)
    check(r.pathname == "xTrayambak/url")

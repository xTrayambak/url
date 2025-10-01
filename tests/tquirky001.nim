import std/unittest
import pkg/url
import pkg/shakar

suite "batch 001 of quirky urls":
  test "kmb://rydcrgvkkwpocdppwczcan.cp/cbjyveokfsbtrlecqzvsn":
    let r = parseURL("kmb://rydcrgvkkwpocdppwczcan.cp/cbjyveokfsbtrlecqzvsn")
    check(r.scheme == "kmb")
    check(r.pathname == "/cbjyveokfsbtrlecqzvsn")
    check(&r.hostname == "rydcrgvkkwpocdppwczcan.cp")

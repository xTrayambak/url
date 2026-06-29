import std/[options, unittest]
import pkg/[shakar, url]

suite "base URLs":
  let b0 = parseURL("https://example.com/a/b/c/d.html")
  let b1 = parseURL("https://thing.app/blog/2ndbirthday/index.html")
  print b0

  test "path shortening":
    let
      t1 = parseURL("e.html", some(b0))
      t2 = parseURL("./e.html", some(b0))
      t3 = parseURL("../e.html", some(b0))
      t4 = parseURL("../../../e.html", some(b0))
      t5 = parseURL("../../../../../e.html", some(b0))

    check(t1.pathname == "/a/b/c/e.html")
    check(t2.pathname == "/a/b/c/e.html")
    check(t3.pathname == "/a/b/e.html")
    check(t4.pathname == "/e.html")
    check(t5.pathname == "/e.html")

  test "some more shortening":
    let
      t1 = parseURL("ceo.jpg", some(b1))
      t2 = parseURL("workers/john.jpg", some(b1))
      t3 = parseURL("testimony/anduril.html", some(b1))
      t4 = parseURL("../facial-age-estimation.html", some(b1))

    check(t1.pathname == "/blog/2ndbirthday/ceo.jpg")
    check(t2.pathname == "/blog/2ndbirthday/workers/john.jpg")
    check(t3.pathname == "/blog/2ndbirthday/testimony/anduril.html")
    check(t4.pathname == "/blog/facial-age-estimation.html")

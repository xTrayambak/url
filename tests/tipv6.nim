## IPv6 parsing tests
import std/unittest
import pkg/[url, shakar]

suite "IPv6 parsing tests":
  test "basics":
    let url1 = parseURL("http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]/hamood.jpeg")

    check(url1.pathname == "/hamood.jpeg")
    check(&url1.hostname == "[2001:0db8:85a3::8a2e:0370:7334]")

    let url2 = parseURL("https://[2001:db8::1]/")
    check(&url2.hostname == "[2001:0db8::0001]")

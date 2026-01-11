import std/unittest
import pkg/url

let u = parseURL("http://example\t.\norg")
echo $u

import std/[options, unittest]
import pkg/url, pkg/shakar
import pkg/pretty

let b = parseURL("https://based.com/hello-world")
let x = parseURL("example.com/path", some(b))

print b
print x

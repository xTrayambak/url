import std/[options, unittest]
import pkg/url, pkg/shakar

# FIXME: This is a very weird quirk. Browsers implement it differently,
# but so does ada-url. The spec is implemented properly in nim-url,
# but browsers use a quirky behaviour as their standard (because
# of course they do, they would be called "sane pieces of engineering"
# if they didn't do that!)

let b = parseURL("https://based.com/hello-world")
let x = parseURL("example.com/path", some(b))

echo $b
echo $x

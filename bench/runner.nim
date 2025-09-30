## benchmark runner
## task: parsing 384 URLs
##
## competitors: treeform/urlly, xTrayambak/nim-url, std/uri
import std/[uri, strutils]
import pkg/[benchy, url, urlly]

var buffer = readFile("bench/urls.txt").splitLines()
discard buffer.pop()

timeIt "treeform/urlly":
  for url in buffer:
    let parsed {.used, volatile.} = urlly.parseUrl(url)

timeIt "std/uri":
  for url in buffer:
    let parsed {.used, volatile.} = uri.parseUri(url)

timeIt "xTrayambak/nim-url":
  for urlS in buffer:
    let parsed {.used, volatile.} = url.parseUrl(urlS)

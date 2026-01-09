import std/unittest
import pkg/url

test "huge/forbidden length URLs (4GB+)":
  var buff = newString(uint32.high.uint64 + 1'u64)
    # Allocate a 4GB + 1 byte buffer. This takes a bit (no pun intended) to fully allocate.

  expect URLParsingError:
    let url1 = parseURL(buff)

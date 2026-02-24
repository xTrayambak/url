## Testing the fast-path for case insensitive view search
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/unittest
import pkg/url/[views, search]

test "case insensitive search fast-path":
  let x = toStringView("hello there. i am totally not losing my mind!")
  check(findInsensitive(x, 'z') == -1)
  check(findInsensitive(x, '!') == int32(x.len - 1))
  check(findInsensitive(x, 'h') == 0)

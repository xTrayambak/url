## Routines for searching `StringView`(s)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/url/views

func find*(view: StringView, needle: StringView): int =
  # TODO: Optimize this with SIMD.
  # It's a ripe target for it.
  let size = view.len
  var i = 0'u32

  while size - i < needle.len:
    if view.beyond(i) == needle:
      return cast[int](i)

    inc i

  -1

func find*(view: StringView, needle: char): int =
  let size = view.len
  var i = 0'u32

  while i < size:
    if view[i] == needle:
      return cast[int](i)

    inc i

  -1

func find*(view: StringView, needle: string): int =
  find(view, toStringView(needle))

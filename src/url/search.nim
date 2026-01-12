## Routines for searching `StringView`(s)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils, strutils]
import pkg/url/views

privateAccess(views.StringView)

# TODO: All of these can probably benefit a lot from SIMD.

func find*(view: views.StringView, needle: StringView): int =
  let size = view.len
  var i = 0'u32

  while size - i < needle.len:
    if view.beyond(i) == needle:
      return cast[int](i)

    inc i

  -1

func find*(view: views.StringView, needle: char): int =
  let size = view.len
  var i = 0'u32

  while i < size:
    if processed(view, view[i]) == needle:
      return cast[int](i)

    inc i

  -1

func findAny*(view: views.StringView, needles: seq[char]): int =
  let size = view.len
  var i = 0'u32

  while i < size:
    if processed(view, view[i]) in needles:
      return cast[int](i)

    inc i

  -1

func find*(view: views.StringView, needle: string): int =
  find(view, toStringView(needle))

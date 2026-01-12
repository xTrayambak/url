## Routines for searching `StringView`(s)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[bitops, importutils, strutils]
import pkg/url/views
import pkg/overdrive

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

func findInsensitive*(view: views.StringView, needle: char): int =
  let size = view.len
  var i = 0'u32

  if not defined(nimUrlNoSimd) and size >= 32:
    # Fast-path for larger strings where case does not matter.
    # Since case does not matter, we can just put the data of the view directly
    # into the SIMD register without the expensive copying that `StringView::$()` performs
    var target: Vector[uint8]
    target.store(cast[uint8](needle))

    let cap = uint32(sizeof(overdrive.RegisterImpl))

    while i + cap <= view.len:
      var blk: Vector[uint8]
      blk.store(cast[ptr uint8](view[i].addr))

      let masked = blk.mask(target)
      if masked != 0:
        let offset = countTrailingZeroBits(masked)
        return cast[int](i) + offset

      i += cap

    while i < view.len:
      if view[i] == needle:
        return cast[int](i)

      inc i
  else:
    while i < size:
      if view[i] == needle:
        return cast[int](i)

      inc i

  return -1

func find*(view: views.StringView, needle: char): int =
  let size = view.len
  var i = 0'u32

  while i < size:
    if processed(view, view[i]) == needle:
      return cast[int](i)

    inc i

  return -1

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

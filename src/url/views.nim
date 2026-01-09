## String views
## This provides zero-cost string reading along with some primitives like suffix deletion.
##
## **NOTE**: A view does not own the data it is pointing to. It is the programmer's job
## to ensure that the underlying data address is not deallocated. If it is, any subsequent
## operations on the view will result in undefined behaviour.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type StringView* = object
  data*: ptr char
  size: uint32

proc `=destroy`*(view: StringView) =
  discard "No work required"

proc `=copy`*(dest: var StringView, source: StringView) =
  dest.data = source.data
  dest.size = source.size

template `[]`*(view: StringView, i: uint32): char =
  when not defined(release):
    assert(view.size > i)

  cast[ptr char]((cast[uint64](view.data) + cast[uint64](i)))[]

template endsWith*(view: StringView, c: char): bool =
  if unlikely(view.size == 0'u32):
    false
  else:
    view[view.size - 1'u32] == c

template len*(view: StringView): uint32 =
  view.size

template removePrefix*(view: var StringView, i: uint32) =
  assert i <= view.size

  view.data = cast[ptr char](cast[uint64](view.data) + cast[uint64](i))
  view.size -= i

template removeSuffix*(view: var StringView, i: uint32) =
  assert i <= view.size
  view.size -= i

template beyond*(view: StringView, offset: uint32): StringView =
  assert offset <= view.size
  StringView(
    data: cast[ptr char](cast[uint64](view.data) + cast[uint64](offset)),
    size: view.size,
  )

template slice*(view: StringView, start: uint32, stop: uint32): StringView =
  StringView(
    data: cast[ptr char](cast[uint64](view.data) + cast[uint64](start)),
    size: stop - start,
  )

template `==`*(a, b: StringView): bool =
  if a.size != b.size:
    false
  else:
    cmpMem(a.data, b.data, a.size) == 0

iterator pairs*(view: StringView): tuple[i: int, v: char] =
  var i = 0'u32

  while i < view.size:
    yield (i: cast[int](i), v: view[i])
    inc i

iterator items*(view: StringView): char =
  var i = 0'u32

  while i < view.size:
    yield view[i]
    inc i

func anyOf*(
    view: StringView, filter: proc(b: char): bool {.noSideEffect, inline.}
): bool {.inline.} =
  # OPTIMIZE: This can probably be made to mimic std::any_of in stdc++ more.
  var i: uint32

  while i < view.size:
    if filter(view[i]):
      return true

    inc i

  false

func `$`*(view: StringView): string =
  ## **NOTE**: This routine creates a copy of the underlying buffer.
  var str = newString(view.size)
  if view.size != 0'u32:
    copyMem(str[0].addr, view.data, view.size)

  ensureMove(str)

func toStringView*(data: ptr char, size: uint32): StringView {.inline.} =
  StringView(data: data, size: size)

func toStringView*(str: string): StringView {.inline.} =
  let size = uint32(len(str))

  StringView(
    data:
      if size != 0:
        str[0].addr
      else:
        nil,
    size: size,
  )

template `==`*(a: StringView, b: string): bool =
  a == toStringView(b)

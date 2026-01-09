## String views
## This provides zero-cost string reading along with some primitives like suffix deletion.
## 
## It also acts as a stateful buffer optionally, meaning it can hold certain flags that are used to avoid conversions to strings (like convert-all-to-lower/upper)
##
## **NOTE**: A view does not own the data it is pointing to. It is the programmer's job
## to ensure that the underlying data address is not deallocated. If it is, any subsequent
## operations on the view will result in undefined behaviour.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/strutils

type
  StringViewFlag* {.pure, size: sizeof(uint8).} = enum
    ## View flags are an optimization to prevent conversions to strings
    ## when possible. For example, if you wanted to turn a view into lowercase
    ## normally, you'd have to do:
    ## .. code-block:: nim
    ##   toStringView(strutils.toLowerAscii($view))
    ## 
    ## Which involves a string copy, which is expensive and bad.
    ## Flags let the programmer signal how a view's content may be mutated,
    ## in a zero-copy manner.
    Heterogenous = 0
    AllLower = 1

  StringView* = object
    data*: ptr char
    size: uint32
    flag: StringViewFlag

proc `=destroy`*(view: StringView) =
  discard "No work required"

proc `=copy`*(dest: var StringView, source: StringView) =
  dest.data = source.data
  dest.size = source.size
  dest.flag = source.flag

template `[]`*(view: StringView, i: uint32): char =
  ## **NOTE**: This does not apply flags.
  when not defined(release):
    assert(view.size > i)

  cast[ptr char]((cast[uint64](view.data) + cast[uint64](i)))[]

template endsWith*(view: StringView, c: char): bool =
  if unlikely(view.size == 0'u32):
    false
  else:
    case view.flag
    of StringViewFlag.Heterogenous:
      view[view.size - 1'u32] == c
    of StringViewFlag.AllLower:
      view[view.size - 1'u32].toLowerAscii() == c

template len*(view: StringView): uint32 =
  view.size

template removePrefix*(view: var StringView, i: uint32) =
  when not defined(release):
    assert i <= view.size

  view.data = cast[ptr char](cast[uint64](view.data) + cast[uint64](i))
  view.size -= i

template removeSuffix*(view: var StringView, i: uint32) =
  when not defined(release):
    assert i <= view.size

  view.size -= i

template beyond*(view: StringView, offset: uint32): StringView =
  when not defined(release):
    assert offset <= view.size

  StringView(
    data: cast[ptr char](cast[uint64](view.data) + cast[uint64](offset)),
    size: view.size,
  )

template slice*(view: StringView, start: uint32, stop: uint32): StringView =
  when not defined(release):
    assert stop >= start

  # debugecho "start: " & $start & ", stop: " & $stop & ", osize: " & $view.len
  StringView(
    data: cast[ptr char](cast[uint64](view.data) + cast[uint64](start)),
    size: stop - start,
  )

template processed*(view: StringView, c: char): char =
  case view.flag
  of StringViewFlag.AllLower:
    toLowerAscii(c)
  of StringViewFlag.Heterogenous:
    c

template `==`*(a, b: StringView): bool =
  if a.size != b.size:
    false
  else:
    a.flag == b.flag and cmpMem(a.data, b.data, a.size) == 0

iterator pairs*(view: StringView): tuple[i: int, v: char] =
  var i = 0'u32

  while i < view.size:
    let v =
      case view.flag
      of StringViewFlag.AllLower:
        toLowerAscii(view[i])
      of StringViewFlag.Heterogenous:
        view[i]

    yield (i: cast[int](i), v: v)
    inc i

iterator items*(view: StringView): char =
  var i = 0'u32

  while i < view.size:
    yield (
      case view.flag
      of StringViewFlag.AllLower:
        toLowerAscii(view[i])
      of StringViewFlag.Heterogenous:
        view[i]
    )
    inc i

func anyOf*(
    view: StringView, filter: proc(b: char): bool {.noSideEffect, inline.}
): bool {.inline.} =
  # OPTIMIZE: This can probably be made to mimic std::any_of in stdc++ more.
  var i: uint32

  while i < view.size:
    if filter(processed(view, view[i])):
      return true

    inc i

  false

template toLowerAscii*(view: StringView): StringView =
  StringView(data: view.data, size: view.size, flag: StringViewFlag.AllLower)

func `$`*(view: StringView): string =
  ## **NOTE**: This routine creates a copy of the underlying buffer.
  var str = newString(view.size)
  if view.size != 0'u32:
    copyMem(str[0].addr, view.data, view.size)

  # Apply any lazy flags
  case view.flag
  of StringViewFlag.AllLower:
    str = toLowerAscii(ensureMove(str))
  of StringViewFlag.Heterogenous:
    discard

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

## Constants from various WHATWG specs
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/strutils

type AsciiSet* = set[char] | set[uint8]

#!fmt: off
const
  ## https://infra.spec.whatwg.org/#c0-control
  ## A C0 control is a code point in the range U+0000 NULL to U+001F INFORMATION SEPARATOR ONE, inclusive.
  C0_CONTROLS*: AsciiSet = { 0'u8 .. 31'u8 }

  ## https://url.spec.whatwg.org/#c0-control-percent-encode-set
  ## The C0 control percent-encode set are the C0 controls and all code points greater than U+007E (~). 
  CONTROLS*: AsciiSet = C0_CONTROLS + { 126'u8 .. uint8.high }
  
  ## https://url.spec.whatwg.org/#url-code-points
  ## The URL code points are ASCII alphanumeric, U+0021 (!), U+0024 ($), U+0026 (&), U+0027 ('), U+0028 LEFT PARENTHESIS, U+0029 RIGHT PARENTHESIS, U+002A (*), U+002B (+), U+002C (,), U+002D (-), U+002E (.), U+002F (/), U+003A (:), U+003B (;), U+003D (=), U+003F (?), U+0040 (@), U+005F (_), U+007E (~), and code points in the range U+00A0 to U+10FFFD, inclusive, excluding surrogates and noncharacters.
  URLCodePoints*: AsciiSet = Digits + Letters + {'!', '$', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '=', '?', '@', '_', '~'} + { cast[char](0xA0) .. cast[char](0xD7FF) } + { cast[char](0xE000) .. cast[char](0x10FFFD) } - { '%' }

  ## https://infra.spec.whatwg.org/#ascii-hex-digit
  ## An ASCII hex digit is an ASCII upper hex digit or ASCII lower hex digit.
  ASCIIHexDigit* = { 'a' .. 'f' } + { 'A' .. 'F' } + Digits
#!fmt: on

{.push inline, raises: [], checks: off.}
func isC0ControlOrSpace*(c: char | uint8): bool =
  cast[uint8](c) <= cast[uint8](' ')

{.pop.}

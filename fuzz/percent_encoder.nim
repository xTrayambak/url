## Fuzzing runner for percent-encode function.
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
#!fmt: off
import pkg/drchaos,
       pkg/url/[unicode, views]
#!fmt: on

func fuzzTarget(data: string) =
  let parsed {.used, volatile.} =
    unicode.percentEncode(toStringView(data), unicode.UserInfoPercentEncode)

defaultMutator(fuzzTarget)

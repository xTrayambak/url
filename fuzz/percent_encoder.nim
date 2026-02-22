## Fuzzing runner for percent-encode function.
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak@disroot.org)
#!fmt: off
import pkg/drchaos,
       pkg/url/[unicode, views]
#!fmt: on

func fuzzTarget(data: string) =
  let parsed {.used, volatile.} =
    unicode.percentEncode(toStringView(data), unicode.UserInfoPercentEncode)

defaultMutator(fuzzTarget)

## Fuzzing runner for entrypoint, uses drchaos
## Using clang is recommended.
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import pkg/[drchaos, url]

func fuzzTarget(data: string) =
  let parsed {.used, volatile.} = tryParseURL(data)

defaultMutator(fuzzTarget)

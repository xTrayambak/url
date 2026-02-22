## Fuzzing runner for entrypoint, uses drchaos
## Using clang is recommended.
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/[drchaos, url]

func fuzzTarget(data: string) =
  let parsed {.used, volatile.} = tryParseURL(data)

defaultMutator(fuzzTarget)

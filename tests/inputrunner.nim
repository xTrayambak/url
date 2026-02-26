import std/os
import pkg/[results, shakar, url]

proc main() {.inline.} =
  if paramCount() < 1:
    quit "Expected 1 param: input name"

  let data = readFile("tests" / "inputs" / paramStr(1) & ".bin")
  echo "Data: " & $data.repr
  let u {.used.} = tryParseUrl(data)

  if !u:
    echo "Parse error: " & $u.error()
  else:
    echo "Successfully parsed"

when isMainModule:
  main()

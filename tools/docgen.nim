## tiny tool to generate docs
import std/[strutils, os, osproc]

let nim = findExe("nim")
assert(nim.len > 0, "Nim cannot be found!")

for kind, file in walkDir("src/url"):
  if kind != pcFile or not file.endsWith(".nim"):
    continue
  echo ">> " & file
  assert(execCmd(nim & " doc --index:on -o:docs/ --path:src " & file) == 0)

assert(execCmd(nim & " doc --index:on -o:docs/index.html --path:src src/url.nim") == 0)

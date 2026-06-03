# Package

version = "0.1.8"
author = "xTrayambak"
description = "A standards-compliant WHATWG URL parser in pure Nim"
license = "BSD-3-Clause"
srcDir = "src"

# Dependencies

requires "nim >= 2.2.0"
requires "results >= 0.5.1"
requires "shakar >= 0.1.3"
requires "https://github.com/xTrayambak/overdrive >= 0.2.0"

taskRequires "benchmark", "benchy >= 0.0.1"

task benchmark, "Run the benchmark suite":
  exec(
    "nim c --define:release --opt:speed --define:danger -o:bench/runner bench/runner.nim"
  )

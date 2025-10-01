# nim-url
This library provides a very fast URL parser written in pure Nim, based upon the [WHATWG URL standard](https://url.spec.whatwg.org/).

It eventually aims to become the de-facto/go-to/no-brainer option for 99.9% of Nim projects requiring a URL parser.

It uses [Kaleidoscope](https://github.com/xTrayambak/kaleidoscope) under the hood for accelerating certain string-related operations via SIMD, making it fast.

## installation
To add this library to your project, run:
```sh
$ nimble add gh:xTrayambak/url
```

## usage
This library uses `Result`(s) and `Option`(s) internally for parsing and other things, but it (mostly) does not force this programming pattern on its consumers.

The higher-level wrapper for `nim-url` provides a `Result` based API as well as an exceptions based API.

```nim
import pkg/url
import pkg/results

# Result-based routines
let url1 = tryParseURL("https://github.com/xTrayambak/url")
assert url1.isOk

# Exceptions-based routines
try:
    let url2 = parseURL("")
except url.URLParsingError as exc:
    echo "oof ouch owie my bones"
    echo url.msg # Contains the error message as to why the parsing failed
```

## acceleration
Some routines in this library are SIMD-accelerated. If you wish to exploit them, append the following flags depending on your binary's architecture target:
- `nimUrlUseSse2`: Enable SSE2 acceleration where possible (x86 and x64 systems)

## contributing
This library welcomes contributions from everyone, but I do recommend you to read [the contributors' guide](CONTRIBUTING.md) prior to making any merge requests or issues.

## attributions
This library's parsing logic is heavily based on the amazing work done by Daniel Lemire and Yagiz Nizipli, et al. on [ada-url](https://github.com/ada-url/ada).

Some parts of the API have borrowed inspiration from the nice programming interface provided by the Servo project's [rust-url](https://github.com/servo/rust-url) crate.

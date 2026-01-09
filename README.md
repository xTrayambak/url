# nim-url
This library provides a very fast URL parser written in pure Nim, based upon the [WHATWG URL standard](https://url.spec.whatwg.org/).

It eventually aims to become the de-facto/go-to/no-brainer option for 99.9% of Nim projects requiring a URL parser.

## features
- Mostly WHATWG compliant, and compliance is increasing.
- Full support for IPv6 parsing and compression.
- Support for opaque paths.
- Support for relative-base URL pairs.

## safety
`nim-url` is fuzzed regularly using libFuzzer and in the most recent fuzzing session (with ~3.4 **million** mutations), no crashes, undefined behaviour or denial of service problems were detected. This was with `--define:danger` turned on.

## speed
In `bench/runner.nim`, this library is tested against `std/uri` (the standard library's **URI** parser — not a **URL** parser!) and treeform's `urlly` library.
This benchmark was done on a AMD Ryzen 5 5600H with 12 cores (albeit none of these parsers use any multithreading techniques, as those are a bit unnecessary).

**Compile Flags Used**: `--define:release --define:nimUrlUseSse2 --define:danger`

```
   min time    avg time  std dv   runs name
   3.923 ms    4.195 ms  ±0.088  x1000 treeform/urlly
   2.590 ms    2.680 ms  ±0.029  x1000 std/uri
   3.711 ms    3.814 ms  ±0.019  x1000 xTrayambak/nim-url
```

## versus other libraries
| Feature                | std/uri                                       | urlly                                               | url      |
|------------------------|-----------------------------------------------|----------------------------------------------------|----------|
| WHATWG Compliance      | No; it is a simple RFC 3986 compliant parser. | No; it is a simple `rfind()`/`find()` based parser. | Yes; it attempts to strictly adhere to the WHATWG URL standards and uses a parser state machine almost identical to what the specifications prescribe. |
| IPv6 Parsing           | Partial; it does not literally parse anything - it just appends IPv6 data to the string buffer. | No; it fails to parse IPv6 addresses and mistakes it for different components. | Yes; it can parse IPv6 addresses as prescribed by the URL standard. |
| IPv6 Compression       | No; it cannot perform IPv6 compression.       | No; it cannot perform IPv6 compression.           | Yes; it can perform IPv6 compression. |
| Relative URLs          | Yes; supports base and relative URLs as per RFC 3986 | No; does not expose any methods for base and relative URLs. | Yes; supports base and relative URLs as per the WHATWG URL standard. |
| Schemes                | Yes; handles all special and non-special schemes as per RFC 3986 | No; fails to parse non-special schemes.          | Yes; handles all special (`http`, `https`, `ws`, etc.) and non-special schemes (`loremipsum`, `steam`, etc.) (except `file://`, this is being worked on) as per the WHATWG specs. |
| Authorization Fields   | Yes                                           | Yes                                                | Yes      |
| Opaque Paths           | No; fails to handle opaque paths (e.g., `mailto:chudkumo@gmail.com`) | No; fails to handle opaque paths                  | Yes; handles opaque paths as per the WHATWG spec. |
| Serialization          | Works, but not WHATWG compliant              | Works, but not WHATWG compliant                   | Works, WHATWG compliant. |
| Error-reporting        | Exceptions only                              | Does not raise any errors, silently processes invalid data. | Allows the usage of either `Result[URL, ParseError]` or `URLParseError`. Errors are very close to their equivalents in the WHATWG specifications. |

## installation
To add this library to your project, run:
```sh
$ nimble add url
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
    echo exc.msg # Contains the error message as to why the parsing failed
```

## acceleration
Some routines in this library are SIMD-accelerated. If you wish to exploit them, append the following flags depending on your binary's architecture target:
- `nimUrlUseSse2`: Enable SSE2 acceleration where possible (x86 and x64 systems)

## contributing
This library welcomes contributions from everyone, but I do recommend you to read [the contributors' guide](CONTRIBUTING.md) prior to making any merge requests or issues.

## attributions
This library's parsing logic is heavily based on the amazing work done by Daniel Lemire and Yagiz Nizipli, et al. on [ada-url](https://github.com/ada-url/ada).

Some parts of the API have borrowed inspiration from the nice programming interface provided by the Servo project's [rust-url](https://github.com/servo/rust-url) crate.

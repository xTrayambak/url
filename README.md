# nim-url
This library provides a very fast URL parser written in pure Nim that aims to be fully compliant to the [WHATWG URL specifications](https://url.spec.whatwg.org/).

It eventually aims to become the de-facto/go-to/no-brainer option for 99.9% of Nim projects requiring a URL parser.

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

## contributing
This library welcomes contributions from everyone, but I do recommend you to read [the contributors' guide](CONTRIBUTING.md) prior to making any merge requests or issues.

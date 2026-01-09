## =======
## nim-url
## =======
## 
## This library (aims to) provide a WHATWG-specifications compliant URL parser in pure Nim, that does not compromise on correctness nor speed.
## It aims to be the go-to, no-brainer library for URL parsing for 99.9% of Nim programs.
import std/options
import pkg/url/[parser, types, url]
import pkg/[results, shakar]

export types
export url.serialize, url.`$`

type URLParsingError* = object of ValueError
  ## The base exception from which all URL parsing failures
  ## derive from. This can be used as a blanket "catch-all"
  ## exception to catch all parsing errors.
  ##
  ## Currently, specialized exceptions do not exist. They will
  ## be added in the future.

func tryParseURL*(
    source: Input, baseUrl: Option[URL] = none(URL)
): Result[URL, ParseError] =
  ## Given a URL string (`source`), parse it using the WHATWG URL specifications parsing algorithm,
  ## to try and produce a valid URL representation.
  ##
  ## This routine returns a `Result[URL, ParseError]`. When parsing is successful, a `URL` can be obtained from this
  ## Result. Otherwise, the `ParseError` can be obtained to understand why the parse was unsuccessful.
  ##
  ## **Algorithm**: https://url.spec.whatwg.org/#url-parsing
  parseURLImpl(input = source, baseUrl = baseUrl)

func parseURL*(
    source: Input, baseUrl: Option[URL] = none(URL)
): URL {.raises: [URLParsingError, ValueError].} =
  ## Given a URL string (`source`), parse it using the WHATWG URL specifications parsing algorithm,
  ## to try and produce a valid URL representation.
  ## 
  ## This routine returns a `URL` upon a successful parse.
  ## If parsing is unsuccessful, a `URLParsingError` is thrown, which can be caught by the programmer.
  ##
  ## **Algorithm**: https://url.spec.whatwg.org/#url-parsing
  {.cast(raises: []).}:
    let parsed = tryParseURL(source = source, baseUrl = baseUrl)

  if !parsed:
    raise newException(URLParsingError, $parsed.error())

  &parsed

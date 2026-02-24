## =====
## url
## =====
## A small shim for allowing `URL`(s) to be turned into `URI`(s) from `std/uri`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

#!fmt: off
import std/[importutils, options, uri]
import pkg/url/[parser, url, views],
       pkg/[results, shakar]
import pkg/url/types {.all.}
#!fmt: on

export types.ParseError

converter toUri(url: types.URL): uri.Uri =
  var uriObj = Uri(
    scheme: url.scheme,
    path: url.pathname,
    opaque: url.flags.contains(URLFlag.HasOpaquePath),
  )
  if url.flags.contains(URLFlag.HasHostname):
    uriObj.hostname = &url.hostname

  if url.flags.contains(URLFlag.HasQuery):
    uriObj.query = &url.query

  if url.flags.contains(URLFlag.HasFragment):
    uriObj.anchor = &url.fragment

  if url.flags.contains(URLFlag.HasPort):
    uriObj.port = $(&url.port)

  uriObj.isIpv6 =
    *parseIpv6(toStringView(uriObj.hostname[0].addr, uint32(uriObj.hostname.len)))
    # FIXME: Surely we can store is-ipv6 as a URLFlag instead of wasting time reparsing the hostname as an IPv6 address?

  ensureMove(uriObj)

func tryParseURL*(input: string): Result[uri.Uri, types.ParseError] =
  let parsed = parseURLImpl(input, none(types.URL)) # TODO: Support for base URIs?
  if !parsed:
    return err(parsed.error())

  ok(&parsed)

func parseURL*(
    input: string
): uri.Uri {.raises: [uri.URIParseError, ValueError, Exception].} =
  let parsed = parseURLImpl(input, none(types.URL))
    # TODO: Same as above, we need support for base URIs.
  if !parsed:
    uriParseError($parsed.error())

  &parsed

## URL parser implementation
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, strutils]
import pkg/url/[checkers, constants, helpers, search, types, url, unicode, views]
import pkg/[results, shakar]

const
  FRAGMENT*: AsciiSet = CONTROLS + {32'u8, 34'u8, 60'u8, 62'u8, 96'u8}
  PATH*: AsciiSet = FRAGMENT + {35'u8, 63'u8}

  USERINFO*: AsciiSet =
    PATH + {47'u8, 58'u8, 59'u8, 61'u8, 64'u8, 91'u8, 92'u8, 93'u8, 94'u8, 124'u8}

  PATH_SEGMENT*: AsciiSet = PATH + {47'u8, 37'u8}

  SPECIAL_PATH_SEGMENT*: AsciiSet = PATH_SEGMENT + {92'u8}

  QUERY*: AsciiSet = CONTROLS + {32'u8, 34'u8, 35'u8, 60'u8, 62'u8}

  SPECIAL_QUERY*: AsciiSet = QUERY + {39'u8}

type State* {.pure.} = enum
  ## **See**: https://url.spec.whatwg.org/#authority-state
  Authority

  ## **See**: https://url.spec.whatwg.org/#scheme-start-state
  SchemeStart

  ## **See**: https://url.spec.whatwg.org/#scheme-state
  Scheme

  ## **See**: https://url.spec.whatwg.org/#host-state
  Host

  ## **See**: https://url.spec.whatwg.org/#no-scheme-state
  NoScheme

  ## **See**: https://url.spec.whatwg.org/#fragment-state
  Fragment

  ## **See**: https://url.spec.whatwg.org/#relative-state
  RelativeScheme

  ## **See**: https://url.spec.whatwg.org/#relative-slash-state
  RelativeSlash

  ## **See**: https://url.spec.whatwg.org/#file-state
  File

  ## **See**: https://url.spec.whatwg.org/#file-host-state
  FileHost

  ## **See**: https://url.spec.whatwg.org/#file-slash-state
  FileSlash

  ## **See**: https://url.spec.whatwg.org/#path-or-authority-state
  PathOrAuthority

  ## **See**: https://url.spec.whatwg.org/#special-authority-ignore-slashes-state
  SpecialAuthorityIgnoreSlashes

  ## **See**: https://url.spec.whatwg.org/#special-authority-slashes-state
  SpecialAuthoritySlashes

  ## **See**: https://url.spec.whatwg.org/#special-relative-or-authority-state
  SpecialRelativeOrAuthority

  ## **See**: https://url.spec.whatwg.org/#query-state
  Query

  ## **See**: https://url.spec.whatwg.org/#path-state
  Path

  ## **See**: https://url.spec.whatwg.org/#path-start-state
  PathStart

  ## **See**: https://url.spec.whatwg.org/#cannot-be-a-base-url-path-state
  OpaquePath

  ## **See**: https://url.spec.whatwg.org/#port-state
  Port

func parseURLImpl*(
    input: Input, baseUrl: Option[URL] = none(URL)
): Result[URL, ParseError] =
  ## This is the main routine that handles the parsing
  ## of a URL string into its structural representation.
  ##
  ## **NOTE**: It is not intended to be called directly and is part of the private API.

  var state = State.SchemeStart
  var url: URL

  # We will immediately refuse to parse any strings
  # that are beyond 4GB in size. They're either a
  # security concern or caused due to an invariant.
  if unlikely(input.len > int(uint32.high)):
    return err(ParseError.TooLarge)

  if input.len < 1:
    return err(ParseError.EmptyUrlBuffer)

  var input =
    if unlikely(hasTabsOrNewline(toStringView(input))):
      removeAsciiTabOrNewline(input)
    else:
      input

  if input.len < 1:
    return err(ParseError.EmptyUrlBuffer)

  var view = toStringView(input[0].addr, uint32(input.len))
  #debugecho "original view: " & toHex(cast[uint64](view[0].addr)) & ", size: " &
  #  $input.len

  trimC0Whitespace(view)

  let fragment = pruneFragment(view)
  # echo "frag for " & $view & ": " & $fragment

  # Now, we can just run the parser state machine
  # to parse all the other URL components.
  var inputPosition: uint32
  let size = view.len

  while inputPosition < size:
    case state
    of State.SchemeStart:
      # If c is an ASCII alpha, append c, lowercased, to buffer and set
      # state to scheme state.
      if inputPosition != size and isAlphaAscii(view[inputPosition]):
        state = State.Scheme
        inc inputPosition
      else:
        # Otherwise, if state override is not given,
        # set state to no scheme state and decrease pointer by 1.
        state = State.NoScheme
    of State.NoScheme:
      # If base is null, or base has an opaque path and c is not U+0023 (#),
      # validation error, return failure.
      if !baseUrl:
        return err(ParseError.MissingSchemeNonRelativeUrl)
      elif (&baseUrl).hasOpaquePath and *fragment and inputPosition == size:
        # Otherwise, if base has an opaque path and c is U+0023 (#),
        # set url's scheme to base's scheme, url's path to base's path,
        # url's query to base's query, and set state to fragment state.
        let base = &baseUrl
        url.copyScheme(base)
        url.hasOpaquePath = true

        url.pathname = base.pathname
        url.updateBaseQuery(base.query)
        url.fragment = fragment

        return ok(move(url))
      elif getSchemeType(&baseUrl) != SchemeType.File:
        # Otherwise, if base's scheme is not "file", set state
        # to relative state and decrease pointer by 1.
        state = State.RelativeScheme
      else:
        # Otherwise, set state to file state and decrease pointer by 1.
        state = State.File
    of State.RelativeScheme:
      # Set url's scheme to base's scheme.
      url.copyScheme(&baseUrl)

      # If c is U+002F (/), then set state to relative slash state.
      if inputPosition != size and view[inputPosition] == '/':
        state = State.RelativeSlash
      elif isSpecial(getSchemeType(url)) and inputPosition != size and
          view[inputPosition] == '\\':
        # Otherwise, if url is special and c is U+005C (\), validation error,
        # set state to relative slash state.
        state = State.RelativeSlash
      else:
        # Set url's username to base's username, url's password to base's
        # password, url's host to base's host, url's port to base's port,
        # url's path to a clone of base's path, and url's query to base's query.
        let base = &baseUrl

        url.username = base.username
        url.password = base.password
        url.hostname = base.hostname
        url.port = base.port
        url.pathname = base.pathname
        url.updateBaseQuery(base.query)

        url.hasOpaquePath = base.hasOpaquePath

        # If c is U+003F (?), then set url's query to the empty string, and
        # state to query state.
        if inputPosition != size and view[inputPosition] == '?':
          state = State.Query
        elif inputPosition != size:
          # Otherwise, if c is not the EOF code point:
          # Set url's query to null.
          url.clearQuery()

          # Shorten url's path.
          var path = url.pathname
          if shortenPath(path, getSchemeType(url)):
            url.pathname = ensureMove(path)

          # Set state to path state and decrease pointer by 1.
          state = State.Path

      inc inputPosition
    of State.Scheme:
      # If c is an ASCII alphanumberic, U+200B (+), U+002D (-), or U+002E (.),
      # append c, lowercased, to buffer.
      while inputPosition != size and isAlnumPlus(view[inputPosition]):
        inc inputPosition

      # Otherwise, if c is U+003A (:), then:
      if inputPosition != size and view[inputPosition] == ':':
        let buff = view.slice(0, inputPosition)
        url.schemeType = parseScheme(buff)

        let schemeType = url.getSchemeType()

        if schemeType == SchemeType.NotSpecial:
          url.nonSpecialScheme = $buff

        # If url's scheme is "file", then:
        if schemeType == SchemeType.File:
          # Set state to file state.
          state = State.File
        elif isSpecial(schemeType) and *baseUrl and getSchemeType(&baseUrl) == schemeType:
          # Otherwise, if url is special, base is non-null, and base's scheme
          # is url's scheme:
          state = State.SpecialRelativeOrAuthority
        elif isSpecial(schemeType):
          # Otherwise, if url is special, set state to special authority
          # slashes state.
          state = State.SpecialAuthoritySlashes
        elif inputPosition + 1 < size and view[inputPosition + 1] == '/':
          # Otherwise, if remaining starts with an U+002F (/), set state to
          # path or authority state and increase pointer by 1.
          state = State.PathOrAuthority
          inc inputPosition
        else:
          # Otherwise, set url's path to the empty string and set state to
          # opaque path state.
          state = State.OpaquePath
      else:
        # Otherwise, if state override is not given, set buffer to the empty
        # string, state to no scheme state, and start over (from the first code
        # point in input).
        state = State.NoScheme
        inputPosition = 0

      inc inputPosition
    of State.SpecialAuthoritySlashes:
      # If c is U+002F (/) and remaining starts with U+002F (/),
      # then set state to special authority ignore slashes state
      # and increase pointer by 1.
      if (size - inputPosition) >= 2 and
          $view.slice(inputPosition, inputPosition + 2) == "//":
        inputPosition += 2

      state = State.SpecialAuthorityIgnoreSlashes
      continue
    of State.SpecialAuthorityIgnoreSlashes:
      # If c is neither U+002F (/) nor U+005C (\), then set
      # state to authority state and decrease pointer by 1.
      while (inputPosition != size) and
          ((view[inputPosition] == '/') or (view[inputPosition] == '\\')):
        inc inputPosition

      state = State.Authority
    of State.Authority:
      # Most URLs have no @. Having no @ tells us that we don't have to worry
      # about AUTHORITY.

      # Check if url data contains an @.
      if findInsensitive(view, '@') == -1:
        state = State.Host
        continue

      var atSignSeen, passwordTokenSeen: bool

      while inputPosition < size:
        let offsetView = view.slice(inputPosition, view.len)

        # The delimiters are @, /, ?, \\
        let location =
          if isSpecial(url.getSchemeType()):
            findAuthorityDelimiterSpecial(offsetView)
          else:
            findAuthorityDelimiter(offsetView)

        let authorityView =
          if location > 0:
            offsetView.slice(0, location)
          else:
            offsetView.slice(0, 0)

        let endOfAuthority = inputPosition + authorityView.len

        # If c is U+0040 (@), then:
        if endOfAuthority < size and view[endOfAuthority] == '@':
          # If atSignSeen is true, then prepend "%40" to the buffer.
          if atSignSeen:
            if passwordTokenSeen:
              url.password = url.password & "%40"
            else:
              url.username = url.username & "%40"

          atSignSeen = true
          if not passwordTokenSeen:
            let passwordTokenLocation = authorityView.find(':')
            passwordTokenSeen = passwordTokenLocation > 0

            if not passwordTokenSeen:
              url.username =
                url.username & percentEncode(authorityView, UserInfoPercentEncode)
            else:
              url.username =
                url.username &
                percentEncode(
                  authorityView.slice(0'u32, cast[uint32](passwordTokenLocation)),
                  UserInfoPercentEncode,
                )

              url.password =
                url.password &
                percentEncode(
                  authorityView.slice(
                    cast[uint32](passwordTokenLocation + 1),
                    cast[uint32](authorityView.len),
                  ),
                  UserInfoPercentEncode,
                )
          else:
            url.password =
              url.password & percentEncode(authorityView, UserInfoPercentEncode)
        elif endOfAuthority == size or (
          endOfAuthority < view.len and (
            view[endOfAuthority] == '/' or view[endOfAuthority] == '?' or
            (isSpecial(getSchemeType(url)) and view[endOfAuthority] == '\\')
          )
        ):
          # Otherwise, if one of the following is true:
          # - c is the EOF code point, U+002F (/), U+003F (?), or U+0023 (#)
          # - url is special and c is U+005C (\)

          # If atSignSeen is true and authority_view is the empty string,
          # validation error, return failure.
          if atSignSeen and authorityView.len < 1:
            return err(ParseError.HostMissing)

          state = State.Host
          break

        if endOfAuthority == size:
          if *fragment:
            url.fragment = fragment

          return ok(move(url))

        inputPosition = endOfAuthority + 1
    of State.Host:
      var hostView = view.slice(inputPosition, view.len)
      let (location, foundColon) =
        getHostDelimiterFunction(isSpecial(url.getSchemeType()), hostView)

      hostView =
        if location > 0:
          hostView.slice(0, location)
        else:
          hostView.slice(0, 0)

      inputPosition =
        if location != cast[uint32](-1):
          inputPosition + location
        else:
          size

      # Otherwise, if c is U+003A (:) and insideBrackets is false, then:
      if foundColon:
        # If the buffer is the empty string, validation error, return failure.
        # Let host be the result of host parsing buffer with url is not special.
        let host = url.parseHost(hostView)
        if *host:
          url.hostname = some(&host)
        else:
          return err(host.error())

        # Set the url's host to host, buffer to the empty string, and state to
        # port state.
        state = State.Port
        inc inputPosition
      else:
        # If url is special and host_view is the empty string,
        # validation error, return failure.
        if hostView.len < 1 and isSpecial(url.getSchemeType()):
          return err(ParseError.EmptyHost)

        # Let host be the result of host parsing host_view with url is not
        # special.
        let host = url.parseHost(hostView)
        if *host:
          url.hostname = some(&host)
        else:
          return err(host.error())

        # Set url's host to host, and state to path start state.
        state = State.PathStart
    of State.PathStart:
      # If url is special, then:
      if isSpecial(url.getSchemeType()):
        # Set state to path state.
        state = State.Path

        if inputPosition == size:
          # Optimization: Avoiding going into PATH state improves the
          # performance of URLs ending with /
          url.pathname = "/"
          url.fragment = fragment

          return ok(ensureMove(url))

        # If c is neither U+002F (/) nor U+005C (\), then decrease pointer
        # by 1. We know that (input_position == input_size) is impossible
        # here, because of the previous if-check.
        if view[inputPosition] != '/' and view[inputPosition] != '\\':
          break

        continue
      elif inputPosition != size and view[inputPosition] == '?':
        # Otherwise, if state override is not given and c is U+003F (?),
        # set url's query to the empty string and state to query state.
        state = State.Query
        continue
      elif inputPosition != size:
        # Otherwise, if c is not the EOF code point:
        state = State.Path

        if view[inputPosition] != '/':
          # If c is not U+002F (/), then decrease pointer by 1.
          break

      inc inputPosition
    of State.Path:
      var view = view.slice(inputPosition + 1, view.len)

      let locOfQuestionMark = findInsensitive(view, '?')

      if locOfQuestionMark > 0:
        state = State.Query
        view = view.slice(0, cast[uint32](locOfQuestionMark))
        inputPosition += view.len + 1
      else:
        inputPosition = size + 1

      url.pathname = url.consumePreparedPath(view)
    of State.OpaquePath:
      var view = view.slice(inputPosition, view.len)
      # If c is U+003F (?), then set URL's query to the empty string and state
      # to query state.
      let location = findInsensitive(view, '?')

      if location > 0:
        view = view.slice(0, cast[uint32](location))
        state = State.Query
        inputPosition += cast[uint32](location)
      else:
        inputPosition = size + 1

      url.hasOpaquePath = true

      # This is a really unlikely scenario in real world. We should not seek
      # to optimize it.
      if view.endsWith(' '):
        let modifiedView = $view.slice(0, view.len - 1) & "%20"
        url.pathname = percentEncode(toStringView(modifiedView), C0ControlPercentEncode)
      else:
        url.pathname = percentEncode(view, C0ControlPercentEncode)
    of State.Port:
      let
        portView = view.slice(inputPosition, view.len)
        increment = url.parsePort(portView, true)

      if !increment:
        return err(ParseError.InvalidPort)
      else:
        inputPosition += &increment

      state = State.PathStart
    of State.RelativeSlash:
      # If url is special and c is U+002F (/) or U+0056 (\), then:
      if isSpecial(getSchemeType(url)) and inputPosition != size and
          (view[inputPosition] == '/' or view[inputPosition] == '\\'):
        # Set state to special authority ignore slashes state.
        state = State.SpecialAuthorityIgnoreSlashes
      elif inputPosition != size and view[inputPosition] == '/':
        # Otherwise, if c is U+002F (/), then set state to authority state.
        state = State.Authority
      else:
        # Otherwise, set:
        # - url's username to base's username,
        # - url's password to base's password,
        # - url's host to base's host,
        # - url's port to base's port,
        # - state to path state, and then, decrease pointer by 1.
        let base = &baseUrl
        url.username = base.username
        url.password = base.password
        url.hostname = base.hostname
        url.port = base.port

        dec inputPosition
        state = State.Path
    of State.PathOrAuthority:
      # If c is U+002F (/), then set state to authority state.
      if inputPosition != size and view[inputPosition] == '/':
        state = State.Authority
        inc inputPosition
      else:
        # Otherwise, set state to path state, and decrease pointer by 1.
        state = State.Path
    of State.SpecialRelativeOrAuthority:
      # If c is U+002F (/) and remaining starts with U+002F (/),
      # then set state to special authority ignore slashes state and increase
      # pointer by 1.
      if size - inputPosition >= 2 and
          view.slice(inputPosition, inputPosition + 1) == "//":
        state = State.SpecialAuthorityIgnoreSlashes
        inputPosition += 2
      else:
        # Otherwise, validation error, set state to relative state and decrease pointer by 1.
        state = State.RelativeScheme
    of State.Query:
      # Let queryPercentEncodeSet be the special-query percent-encode set
      # if url is special; otherwise the query percent-encode set.
      let queryPercentEncodeSet =
        if isSpecial(getSchemeType(url)):
          SpecialQueryPercentEncode
        else:
          QueryPercentEncode

      # Percent-encode after encoding, with encoding, buffer, and
      # queryPercentEncodeSet, and append the result to url's query.
      url.updateBaseQuery(
        some($view.slice(inputPosition + 1, view.len)), queryPercentEncodeSet
      )
      if *fragment:
        url.fragment = fragment

      return ok(ensureMove(url))
    of State.File:
      let fileView = view.slice(inputPosition, view.len)
      url.schemeType = SchemeType.File

      # Set URL's host to the empty string.
      url.hostname = none(string)

      # If c is U+002F (/) or U+005C (\), then:
      if inputPosition != size and
          (view[inputPosition] == '/' or view[inputPosition] == '\\'):
        # Set state to file slash state.
        state = State.FileSlash
      elif *baseUrl and getSchemeType(&baseUrl) == SchemeType.File:
        # Otherwise, if base is non-null and base's scheme is "file":
        # Set url's host to base's host, url's path to a clone of base's
        # path, and url's query to base's query.
        let base = &baseUrl

        url.hostname = base.hostname
        url.pathname = base.pathname
        url.query = base.query
        url.hasOpaquePath = base.hasOpaquePath

        # If c is U+003F (?), then set url's query to the empty string and
        # state to query state.
        if inputPosition != size and view[inputPosition] == '?':
          state = State.Query
        elif inputPosition != size:
          # Otherwise, if c is not the EOF code point:
          # Set url's query to null.
          url.query = none(string)

          # If the code point substring from pointer to the end of input does
          # not start with a Windows drive letter, then shorten url's path.
          if not isWindowsDriveLetter(fileView):
            var path = url.pathname
            discard shortenPath(path, SchemeType.File)

            url.pathname = ensureMove(path)
          else:
            # Otherwise:
            # Set URL's path to an empty list.
            url.clearPathname()
            url.hasOpaquePath = true

          # Set state to path state and decrease pointer by 1.
          state = State.Path
      else:
        # Otherwise, set state to path state, and decrease pointer by 1.
        state = State.Path

      inc inputPosition
    of State.FileSlash:
      # If c is U+002F (/) or U+005C (\), then:
      if inputPosition != size and
          (view[inputPosition] == '/' or view[inputPosition] == '\\'):
        # Set state to file host state.
        state = State.FileHost
        inc inputPosition
      else:
        # If base is non-null and base's scheme is "file", then:
        if *baseUrl and getSchemeType(&baseUrl) == SchemeType.File:
          let base = &baseUrl

          # Set url's host to base's host.
          url.hostname = base.hostname

          # If the code point substring from pointer to the end of input does
          # not start with a Windows drive letter and base's path[0] is a
          # normalized Windows drive letter, then append base's path[0] to
          # url's path.
          if base.pathname.len > 0:
            if not isWindowsDriveLetter(view.slice(inputPosition, view.len)):
              var firstBaseUrlPath = toStringView(base.pathname).slice(1, view.len)
              let loc = firstBaseUrlPath.findInsensitive('/')
              if loc != -1:
                resize(firstBaseUrlPath, uint32(loc))

              if isNormalizedWindowsDriveLetter(firstBaseUrlPath):
                url.pathname &= '/'
                url.pathname &= $firstBaseUrlPath

        # Set state to path state, and decrease pointer by 1.
        state = State.Path
    of State.FileHost:
      let
        view = view.slice(inputPosition, view.len)
        location = view.findAny(@['/', '\\', '?'])
        fileHostBuffer =
          toStringView(view.data, (if location == -1: view.len
            else: uint32(location)))

      # debugecho "fhb: " & $filehostbuffer & "; loc=" & $location

      if isWindowsDriveLetter(fileHostBuffer):
        state = State.Path
      elif fileHostBuffer.len < 1:
        # Set url's host to an empty string.
        url.hostname = none(string)

        # Set state to path start state.
        state = State.PathStart
      else:
        let consumedBytes = fileHostBuffer.len
        inputPosition += consumedBytes

        # Let host be the result of host parsing buffer with url is not special.
        let host = parseHost(url, fileHostBuffer)
        if !host:
          return ok(ensureMove(url))

        url.hostname = some(&host)

        # If host is "localhost", then set host to an empty string.
        if *url.hostname and &url.hostname == "localhost":
          url.hostname = none(string)

        # Set buffer to an empty string and state to path start state.
        state = State.PathStart
    else:
      break

  if *fragment:
    url.fragment = fragment

  ok(ensureMove(url))

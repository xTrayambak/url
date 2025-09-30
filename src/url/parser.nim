## URL parser implementation
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/[importutils, options, strutils]
import pkg/url/[constants, helpers, types, url]
import pkg/[kaleidoscope/search, results, shakar]

const
  FRAGMENT*: AsciiSet = CONTROLS + {' ', '"', '<', '>', '`'}
  PATH*: AsciiSet = FRAGMENT + {'#', '?'}

  USERINFO*: AsciiSet = PATH + {'/', ':', ';', '=', '@', '[', '\\', ']', '^', '|'}

  PATH_SEGMENT*: AsciiSet = PATH + {'/', '%'}

  SPECIAL_PATH_SEGMENT*: AsciiSet = PATH_SEGMENT + {'\\'}

  QUERY*: AsciiSet = CONTROLS + {' ', '"', '#', '<', '>'}

  SPECIAL_QUERY*: AsciiSet = QUERY + {'\''}

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

proc parseURLImpl*(
    input: Input, baseUrl: Option[URL] = none(URL)
): Result[URL, ParseError] =
  ## This is the main routine that handles the parsing
  ## of a URL string into its structural representation.

  var state = State.SchemeStart
  var url: URL

  # We will immediately refuse to parse any strings
  # that are beyond 4GB in size. They're either a
  # security concern or caused due to an invariant.
  if unlikely(input.len > int(uint32.high)):
    return err(ParseError.TooLarge)

  # Going forward, input.len() is in { 0 .. uint32.high }.
  # If we are provided with an invalid base, or it was invalid,
  # we must return with an error.
  # TODO: implement this logic

  var urlData = newString(input.len)
  if input.len > 0:
    copyMem(urlData[0].addr, input[0].addr, input.len)
  else:
    return err(ParseError.EmptyUrlBuffer)

  trimC0Whitespace(urlData)

  let fragment = pruneFragment(urlData)

  # Now, we can just run the parser state machine
  # to parse all the other URL components.
  var inputPosition: uint64
  let size = uint64(urlData.len)

  while inputPosition < size:
    # echo "fsm iter " & $inputPosition & "/" & $size & ' ' & $state
    case state
    of State.SchemeStart:
      # If c is an ASCII alpha, append c, lowercased, to buffer and set
      # state to scheme state.
      if inputPosition != size and isAlphaAscii(urlData[inputPosition]):
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

      # TODO: Implement the rest of the spec
    of State.Scheme:
      # If c is an ASCII alphanumberic, U+200B (+), U+002D (-), or U+002E (.),
      # append c, lowercased, to buffer.
      while inputPosition != size and isAlnumPlus(urlData[inputPosition]):
        inc inputPosition

      # Otherwise, if c is U+003A (:), then:
      if inputPosition != size and urlData[inputPosition] == ':':
        let buff = urlData[0 ..< inputPosition]
        url.specialScheme = parseScheme(buff)

        if url.specialScheme == SchemeType.NotSpecial:
          url.nonSpecialScheme = buff

        # If url's scheme is "file", then:
        if url.specialScheme == SchemeType.File:
          # Set state to file state.
          state = State.File
        elif url.specialScheme.isSpecial and *baseUrl and
            (&baseUrl).specialScheme == url.specialScheme:
          # Otherwise, if url is special, base is non-null, and base's scheme
          # is url's scheme:
          state = State.SpecialRelativeOrAuthority
        elif url.specialScheme.isSpecial:
          # Otherwise, if url is special, set state to special authority
          # slashes state.
          state = State.SpecialAuthoritySlashes
        elif inputPosition + 1 < size and urlData[inputPosition + 1] == '/':
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
          urlData[inputPosition .. inputPosition + 1] == "//":
        inputPosition += 2

      state = State.SpecialAuthorityIgnoreSlashes
      continue
    of State.SpecialAuthorityIgnoreSlashes:
      # If c is neither U+002F (/) nor U+005C (\), then set
      # state to authority state and decrease pointer by 1.
      while (inputPosition != size) and
          ((urlData[inputPosition] == '/') or (urlData[inputPosition] == '\\')):
        inc inputPosition

      state = State.Authority
    of State.Authority:
      # Most URLs have no @. Having no @ tells us that we don't have to worry
      # about AUTHORITY.

      # Check if url data contains an @.
      if search.find(urlData, "@") == -1:
        # TODO: Implement find(string, char) in Kaleidoscope. This is wasteful!
        state = State.Host
        continue

      var atSignSeen, passwordTokenSeen: bool

      while true:
        let view = urlData[inputPosition ..< urlData.len]

        # The delimiters are @, /, ?, \\
        let location =
          if url.specialScheme.isSpecial:
            findAuthorityDelimiterSpecial(view)
          else:
            findAuthorityDelimiter(view)

        # TODO: Complete this
    of State.Host:
      var hostView = urlData[inputPosition ..< urlData.len]
      let (location, foundColon) =
        getHostDelimiterFunction(url.specialScheme.isSpecial(), hostView)
      hostView = hostView[0 ..< location]

      inputPosition =
        if location != cast[uint64](-1):
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
        if hostView.len < 1 and url.specialScheme.isSpecial:
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
      if url.specialScheme.isSpecial:
        # Set state to path state.
        state = State.Path

        # If c is neither U+002F (/) nor U+005C (\), then decrease pointer
        # by 1. We know that (input_position == input_size) is impossible
        # here, because of the previous if-check.
        if urlData[inputPosition] != '/' and urlData[inputPosition] != '\\':
          break
      elif inputPosition != size and urlData[inputPosition] == '?':
        # Otherwise, if state override is not given and c is U+003F (?),
        # set url's query to the empty string and state to query state.
        state = State.Query
      elif inputPosition != size:
        # Otherwise, if c is not the EOF code point:
        state = State.Path

        if urlData[inputPosition] != '/':
          # If c is not U+002F (/), then decrease pointer by 1.
          break

      inc inputPosition
    of State.Path:
      var view = urlData[inputPosition ..< urlData.len]

      let locOfQuestionMark = search.find(view, "?")
        # TODO: Implement find(string, char) in Kaleidoscope

      if locOfQuestionMark != -1:
        state = State.Query
        view = view[0 ..< locOfQuestionMark]
        inputPosition += uint64(view.len + 1)
      else:
        inputPosition = size + 1

      url.path = url.consumePreparedPath(view).split('/')
    #[ of State.Fragment:
      var fragment = newStringOfCap(size - inputPosition)
        # The fragment is guaranteed to be the last parsed component, so we can make a proper calculation as to how many bytes we'll need.

      while inputPosition < size:
        let c = urlData[inputPosition]

        case c
        of URLCodePoints:
          # 3. UTF-8 percent-encode c using the fragment percent-encode set and append the result to url’s fragment.
          # FIXME: do percent encoding here!
          fragment &= c
        of '%':
          # 2. If c is U+0025 (%) and remaining does not start with two ASCII hex digits, invalid-URL-unit validation error.
          let remainingSize = size - inputPosition
          if remainingSize < 2 or (urlData[inputPosition + 1] notin ASCIIHexDigit) or
              (urlData[inputPosition + 2] notin ASCIIHexDigit):
            return err(ParseError.InvalidUrlUnit)
        else:
          # 1. If c is not a URL code point and not U+0025 (%), invalid-URL-unit validation error.
          return err(ParseError.InvalidUrlUnit)

        inc inputPosition

      url.fragment = some(ensureMove(fragment))
      break ]#
    of State.OpaquePath:
      var view = urlData[inputPosition ..< urlData.len]
      # If c is U+003F (?), then set URL's query to the empty string and state
      # to query state.
      let location = search.find(view, "?")

      if location != -1:
        view = view[0 ..< location]
        state = State.Query
        inputPosition += uint64(location + 1)
      else:
        inputPosition = size + 1

      url.hasOpaquePath = true

      # This is a really unlikely scenario in real world. We should not seek
      # to optimize it.
      if view.endsWith(' '):
        let modifiedView = view[0 ..< view.len] & "%20"
    else:
      break

  ok(ensureMove(url))

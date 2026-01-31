import std/unittest
import pkg/url

test "serialize with port":
  check(
    parseURL("http://localhost:8080/api/v1/destroy").serialize ==
      "http://localhost:8080/api/v1/destroy"
  )

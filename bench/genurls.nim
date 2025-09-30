import std/[random, strutils]

var buffer: string
randomize()

proc randChars(n: int): string =
  var buff = newString(n)
  for i in 0 ..< n:
    buff[i] = sample(Letters).toLowerAscii

  ensureMove(buff)

for i in 0 .. 10_000:
  # scheme
  case rand(0 .. 4)
  of 0:
    buffer &= "https://"
  of 1:
    buffer &= "http://"
  of 2:
    buffer &= "ws://"
  of 3:
    buffer &= "wss://"
  of 4:
    buffer &= randChars(rand(2 .. 5)) & "://"
  else:
    discard

  # hostname
  buffer &= randChars(rand(3 .. 28)).toLowerAscii

  buffer &= '.'

  # tld
  buffer &= randChars(rand(2 .. 3)).toLowerAscii

  # path
  if rand(0 .. 1) == 0:
    buffer &= '/'
    buffer &= randChars(rand(2 .. 28))

    if rand(0 .. 1) == 1:
      buffer &= '#'
      buffer &= randChars(rand(2 .. 28))

  buffer &= '\n'

writeFile("bench/urls.txt", buffer)

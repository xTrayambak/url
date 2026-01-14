## Serialization routines
##
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)
import std/strutils

func findLongestSequenceOfIpv6Pieces*(
    address: array[8, uint16], compress, compressLength: var uint64
) {.raises: [].} =
  var i: uint64
  while i < 8:
    if address[i] == 0:
      var next = i + 1
      while next != 8 and address[next] == 0:
        inc next
      let count = next - i

      if compressLength < count:
        compressLength = count
        compress = uint64(i)
        if next == 8:
          break
        i = next

    inc i

func serializeIpv6*(address: array[8, uint16]): string {.raises: [].} =
  var
    compressLength = 0'u64
    compress = 0'u64

  findLongestSequenceOfIpv6Pieces(address, compress, compressLength)

  if compressLength <= 1:
    compressLength = 8'u64
    compress = 8'u64

  var output = newString(4 * 8 + 9)
  var pieceIndex = 0'u64
  var point = 1

  output[0] = '['
  while true:
    if pieceIndex == compress:
      output[point] = ':'
      inc point
      # If we skip a value initially, we need to write '::', otherwise
      # a single ':' will do since it follows a previous ':'

      if pieceIndex == 0:
        output[point] = ':'
        inc point

      pieceIndex += compressLength
      if pieceIndex == 8:
        break

    let converted = toLowerAscii(toHex(address[pieceIndex]))
    output[point ..< converted.len] = converted
    point += converted.len
    inc pieceIndex

    if pieceIndex == 8:
      break

    output[point] = ':'
    inc point

  output[point] = ']'
  inc point
  output.setLen(point)

  ensureMove(output)

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart extract_encryption_samples.dart <pdf-path>');
    exitCode = 64;
    return;
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${args.first}');
    exitCode = 66;
    return;
  }
  final bytes = file.readAsBytesSync();
  final content = latin1.decode(bytes, allowInvalid: true);
  final patterns = <String>{
    '/O',
    '/U',
    '/OE',
    '/UE',
    '/Perms',
    '/P',
    '/R',
    '/Length',
    '/V',
    '/EncryptMetadata',
  };
  final results = <String, dynamic>{};
  for (final pattern in patterns) {
    var index = content.indexOf(pattern);
    while (index != -1) {
      final nextIndex = index + pattern.length;
      final nextByte = nextIndex < bytes.length ? bytes[nextIndex] : -1;
      if ((pattern == '/O' ||
              pattern == '/U' ||
              pattern == '/OE' ||
              pattern == '/UE' ||
              pattern == '/Perms' ||
              pattern == '/EncryptMetadata') &&
          nextByte != 0x20 && nextByte != 0x3c && nextByte != 0x28) {
        index = content.indexOf(pattern, nextIndex);
        continue;
      }
      final valueStart = nextIndex;
      final token = _parseToken(bytes, valueStart);
      results.putIfAbsent(pattern, () => token.toJson(index));
      index = content.indexOf(pattern, nextIndex);
    }
  }
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}

_ParsedToken _parseToken(List<int> bytes, int start) {
  // Skip whitespace.
  var offset = start;
  while (offset < bytes.length) {
    final byte = bytes[offset];
    if (byte == 0x20 || byte == 0x0d || byte == 0x0a || byte == 0x09) {
      offset++;
      continue;
    }
    break;
  }
  if (offset >= bytes.length) {
    return _ParsedToken(offset, <int>[]);
  }
  final first = bytes[offset];
  if (first == 0x3c) {
    // Hex string
    final end = bytes.indexOf(0x3e, offset + 1);
    final hexString = latin1.decode(bytes.sublist(offset + 1, end), allowInvalid: true)
        .replaceAll(RegExp(r'\s+'), '');
    final result = <int>[];
    for (var i = 0; i < hexString.length; i += 2) {
      final chunk = hexString.substring(i, math.min(i + 2, hexString.length));
      if (chunk.length < 2) {
        result.add(int.parse(chunk + '0', radix: 16));
      } else {
        result.add(int.parse(chunk, radix: 16));
      }
    }
    return _ParsedToken(end + 1, result);
  }
  if (first == 0x28) {
    final result = <int>[];
    var i = offset + 1;
    var nesting = 1;
    while (i < bytes.length && nesting > 0) {
      final b = bytes[i];
      if (b == 0x5c) {
        if (i + 1 < bytes.length) {
          final next = bytes[i + 1];
          switch (next) {
            case 0x6e: // n
              result.add(0x0a);
              break;
            case 0x72: // r
              result.add(0x0d);
              break;
            case 0x74: // t
              result.add(0x09);
              break;
            case 0x62: // b
              result.add(0x08);
              break;
            case 0x66: // f
              result.add(0x0c);
              break;
            case 0x28: // (
            case 0x29: // )
            case 0x5c: // \
              result.add(next);
              break;
            default:
              if (next >= 0x30 && next <= 0x37) {
                // Up to three octal digits.
                var octal = String.fromCharCodes(<int>[next]);
                var count = 1;
                while (count < 3 && i + 1 + count < bytes.length) {
                  final digit = bytes[i + 1 + count];
                  if (digit < 0x30 || digit > 0x37) {
                    break;
                  }
                  octal += String.fromCharCodes(<int>[digit]);
                  count++;
                }
                result.add(int.parse(octal, radix: 8));
                i += count;
              } else {
                result.add(next);
              }
          }
          i += 2;
          continue;
        }
      } else if (b == 0x28) {
        nesting++;
      } else if (b == 0x29) {
        nesting--;
        if (nesting == 0) {
          i++;
          break;
        }
      }
      if (nesting > 0) {
        result.add(b);
        i++;
      }
    }
    return _ParsedToken(i, result);
  }
  if ((first >= 0x30 && first <= 0x39) || first == 0x2d) {
      if (first == 0x74 || first == 0x66 || first == 0x54 || first == 0x46) {
        // true/false or T/F
        final builder = StringBuffer();
        var i = offset;
        while (i < bytes.length) {
          final b = bytes[i];
          if ((b >= 0x41 && b <= 0x5a) || (b >= 0x61 && b <= 0x7a)) {
            builder.writeCharCode(b);
            i++;
          } else {
            break;
          }
        }
        final text = builder.toString();
        return _ParsedToken(i, text.codeUnits, text: text);
      }
    final builder = StringBuffer();
    var i = offset;
    while (i < bytes.length) {
      final b = bytes[i];
      if ((b >= 0x30 && b <= 0x39) || b == 0x2d) {
        builder.writeCharCode(b);
        i++;
      } else {
        break;
      }
    }
    final value = builder.toString();
    return _ParsedToken(i, value.codeUnits, text: value);
  }
  return _ParsedToken(offset + 1, <int>[]);
}

class _ParsedToken {
  _ParsedToken(this.endOffset, List<int> bytes, {String? text})
      : bytes = List<int>.unmodifiable(bytes),
        hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        raw = text ?? bytes.toString();

  final int endOffset;
  final List<int> bytes;
  final String hex;
  final String raw;

  Map<String, Object?> toJson(int index) => <String, Object?>{
        'offset': index,
        'length': bytes.length,
        'hex': hex,
        'text': raw,
      };
}

import 'dart:math' as math;
import 'dart:typed_data';

import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';

class Predictor {
  const Predictor._();

  static Uint8List apply(Uint8List input, COSDictionary decodeParams) {
    final predictor = decodeParams.getInt(COSName.predictor, 1) ?? 1;
    if (predictor <= 1) {
      return input;
    }

    final colors = math.max(1, math.min(decodeParams.getInt(COSName.colors, 1) ?? 1, 32));
    final bitsPerComponent = decodeParams.getInt(COSName.bitsPerComponent, 8) ?? 8;
    final columns = math.max(1, decodeParams.getInt(COSName.columns, 1) ?? 1);

    final rowLength = calculateRowLength(colors, bitsPerComponent, columns);
    final bool predictorPerRow = predictor >= 10;

    final output = BytesBuilder(copy: false);
    var offset = 0;
    var currentPredictor = predictor;
    var currentRow = Uint8List(rowLength);
    var lastRow = Uint8List(rowLength);

    while (offset < input.length) {
      if (predictorPerRow) {
        currentPredictor = 10 + (input[offset] & 0xff);
        offset++;
        if (offset >= input.length && rowLength == 0) {
          break;
        }
      }

      final remaining = input.length - offset;
      final toRead = remaining >= rowLength ? rowLength : remaining;
      currentRow.fillRange(0, rowLength, 0);
      if (toRead > 0) {
        currentRow.setRange(0, toRead, input, offset);
        offset += toRead;
      }

      decodePredictorRow(
        currentPredictor,
        colors,
        bitsPerComponent,
        columns,
        currentRow,
        lastRow,
      );
      output.add(currentRow);

      final temp = lastRow;
      lastRow = currentRow;
      currentRow = temp;
    }

    return output.toBytes();
  }

  static void decodePredictorRow(
    int predictor,
    int colors,
    int bitsPerComponent,
    int columns,
    Uint8List actline,
    Uint8List lastline,
  ) {
    if (predictor == 1) {
      return;
    }

    final bitsPerPixel = colors * bitsPerComponent;
    final bytesPerPixel = ((bitsPerPixel) + 7) >> 3;
    final rowlength = actline.length;

    switch (predictor) {
      case 2:
        if (bitsPerComponent == 8) {
          for (var p = bytesPerPixel; p < rowlength; ++p) {
            final sub = actline[p] & 0xff;
            final left = actline[p - bytesPerPixel] & 0xff;
            actline[p] = (sub + left).toUnsigned(8);
          }
          break;
        }
        if (bitsPerComponent == 16) {
          for (var p = bytesPerPixel; p < rowlength - 1; p += 2) {
            final sub = ((actline[p] & 0xff) << 8) + (actline[p + 1] & 0xff);
            final left = ((actline[p - bytesPerPixel] & 0xff) << 8) +
                (actline[p - bytesPerPixel + 1] & 0xff);
            final value = sub + left;
            actline[p] = ((value >> 8) & 0xff).toUnsigned(8);
            actline[p + 1] = (value & 0xff).toUnsigned(8);
          }
          break;
        }
        if (bitsPerComponent == 1 && colors == 1) {
          for (var p = 0; p < rowlength; ++p) {
            for (var bit = 7; bit >= 0; --bit) {
              final sub = (actline[p] >> bit) & 1;
              if (p == 0 && bit == 7) {
                continue;
              }
              final left = bit == 7
                  ? actline[p - 1] & 1
                  : (actline[p] >> (bit + 1)) & 1;
              final sum = (sub + left) & 1;
              if (sum == 0) {
                actline[p] = (actline[p] & ~(1 << bit)).toUnsigned(8);
              } else {
                actline[p] = (actline[p] | (1 << bit)).toUnsigned(8);
              }
            }
          }
          break;
        }
        final elements = columns * colors;
        for (var p = colors; p < elements; ++p) {
          final bytePosSub = (p * bitsPerComponent) >> 3;
          final bitPosSub = 8 - (p * bitsPerComponent % 8) - bitsPerComponent;
          final bytePosLeft = ((p - colors) * bitsPerComponent) >> 3;
          final bitPosLeft =
              8 - ((p - colors) * bitsPerComponent % 8) - bitsPerComponent;

          final sub = getBitSeq(actline[bytePosSub], bitPosSub, bitsPerComponent);
          final left = getBitSeq(actline[bytePosLeft], bitPosLeft, bitsPerComponent);
          actline[bytePosSub] = calcSetBitSeq(
            actline[bytePosSub],
            bitPosSub,
            bitsPerComponent,
            sub + left,
          ).toUnsigned(8);
        }
        break;
      case 10:
        break;
      case 11:
        for (var p = bytesPerPixel; p < rowlength; ++p) {
          final sub = actline[p];
          final left = actline[p - bytesPerPixel];
          actline[p] = (sub + left).toUnsigned(8);
        }
        break;
      case 12:
        for (var p = 0; p < rowlength; ++p) {
          final up = actline[p] & 0xff;
          final prior = lastline[p] & 0xff;
          actline[p] = ((up + prior) & 0xff).toUnsigned(8);
        }
        break;
      case 13:
        for (var p = 0; p < rowlength; ++p) {
          final avg = actline[p] & 0xff;
          final left = p - bytesPerPixel >= 0
              ? actline[p - bytesPerPixel] & 0xff
              : 0;
          final up = lastline[p] & 0xff;
          actline[p] = ((avg + ((left + up) >> 1)) & 0xff).toUnsigned(8);
        }
        break;
      case 14:
        for (var p = 0; p < rowlength; ++p) {
          final paeth = actline[p] & 0xff;
          final a =
              p - bytesPerPixel >= 0 ? actline[p - bytesPerPixel] & 0xff : 0;
          final b = lastline[p] & 0xff;
          final c = p - bytesPerPixel >= 0
              ? lastline[p - bytesPerPixel] & 0xff
              : 0;
          final value = a + b - c;
          final absa = (value - a).abs();
          final absb = (value - b).abs();
          final absc = (value - c).abs();

          if (absa <= absb && absa <= absc) {
            actline[p] = ((paeth + a) & 0xff).toUnsigned(8);
          } else if (absb <= absc) {
            actline[p] = ((paeth + b) & 0xff).toUnsigned(8);
          } else {
            actline[p] = ((paeth + c) & 0xff).toUnsigned(8);
          }
        }
        break;
      default:
        break;
    }
  }

  static int calculateRowLength(int colors, int bitsPerComponent, int columns) {
    final bitsPerPixel = colors * bitsPerComponent;
    return ((columns * bitsPerPixel) + 7) >> 3;
  }

  static int getBitSeq(int byteValue, int startBit, int bitSize) {
    final mask = (1 << bitSize) - 1;
    return (byteValue >> startBit) & mask;
  }

  static int calcSetBitSeq(int byteValue, int startBit, int bitSize, int value) {
    final mask = (1 << bitSize) - 1;
    final truncated = value & mask;
    final cleared = byteValue & ~(mask << startBit);
    return cleared | (truncated << startBit);
  }
}

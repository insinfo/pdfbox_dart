import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/dct_filter.dart';
import 'package:pdfbox_dart/src/pdfbox/filter/decode_options.dart';
import 'package:test/test.dart';

void main() {
  group('DCTFilter', () {
    test('decodes JPEG stream to RGBA samples', () {
      final filter = DCTFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName.dctDecode);

      final source = img.Image(width: 2, height: 1);
      source.setPixelRgba(0, 0, 255, 0, 0, 255);
      source.setPixelRgba(1, 0, 0, 255, 0, 255);

      final jpegBytes = Uint8List.fromList(img.encodeJpg(source, quality: 100));

      final result = filter.decode(jpegBytes, parameters, 0);
      expect(result.data.length, equals(2 * 1 * 4));

      final firstPixel = result.data.sublist(0, 4);
      expect(firstPixel[0], greaterThan(firstPixel[1]));
      expect(firstPixel[0], greaterThan(firstPixel[2]));

      final secondPixel = result.data.sublist(4, 8);
      expect(secondPixel[1], greaterThan(secondPixel[0]));
      expect(secondPixel[1], greaterThan(secondPixel[2]));

      final info = result.decodeResult.colorSpace as JpegColorInfo;
      expect(info.originalChannelCount, equals(3));
      expect(info.outputChannelCount, equals(4));
      expect(info.convertedToRgba, isTrue);
      expect(info.possibleCmyk, isFalse);
    });

    test('honours preserveRawDct option', () {
      final filter = DCTFilter();
      final parameters = COSDictionary()
        ..setItem(COSName.filter, COSName.dctDecode);

      final source = img.Image(width: 1, height: 1);
      source.setPixelRgba(0, 0, 120, 200, 40, 255);
      final jpegBytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));

      final options = const DecodeOptions(preserveRawDct: true);
      final result = filter.decode(jpegBytes, parameters, 0, options: options);

      expect(result.data.length, equals(3));
      final info = result.decodeResult.colorSpace as JpegColorInfo;
      expect(info.originalChannelCount, equals(3));
      expect(info.outputChannelCount, equals(3));
      expect(info.convertedToRgba, isFalse);
    });
  });
}

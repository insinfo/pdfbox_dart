import 'package:test/test.dart';
import 'package:pdfbox_dart/src/jbig2/bitmap.dart';
import 'package:pdfbox_dart/src/jbig2/image/bitmaps.dart';
import 'package:pdfbox_dart/src/jbig2/util/combination_operator.dart';
import 'package:pdfbox_dart/src/jbig2/util/rectangle.dart';
import 'dart:math';

void main() {
  group('BitmapsBlitTest', () {
    test('testCompleteBitmapTransfer', () {
      // Instead of loading from file, create a random bitmap
      final width = 100;
      final height = 100;
      final src = Bitmap(width, height);
      final rng = Random();
      for (int i = 0; i < src.getByteArray().length; i++) {
        src.setByte(i, rng.nextInt(256));
      }

      final dst = Bitmap(width, height);
      Bitmaps.blit(src, dst, 0, 0, CombinationOperator.REPLACE);

      expect(dst.getByteArray(), equals(src.getByteArray()));
    });

    test('test', () {
      // Create a dst bitmap with some data
      final width = 500;
      final height = 500;
      final dst = Bitmap(width, height);
      final rng = Random();
      for (int i = 0; i < dst.getByteArray().length; i++) {
        dst.setByte(i, rng.nextInt(256));
      }

      final roi = Rectangle(100, 100, 100, 100);
      final src = Bitmap(roi.width, roi.height);
      // src is blank (all zeros)
      
      Bitmaps.blit(src, dst, roi.x, roi.y, CombinationOperator.REPLACE);

      final dstRegionBitmap = Bitmaps.extract(roi, dst);

      expect(dstRegionBitmap.getByteArray(), equals(src.getByteArray()));
    });
  });
}

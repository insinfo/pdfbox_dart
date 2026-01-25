import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart' show ImageBuffer;
import 'package:image/image.dart' as img;

class GoldenDiff {
  GoldenDiff({
    required this.mismatchedPixels,
    required this.totalPixels,
    required this.firstMismatch,
  });

  final int mismatchedPixels;
  final int totalPixels;
  final ({int x, int y, int expected, int actual})? firstMismatch;

  double get mismatchRatio =>
      totalPixels == 0 ? 0 : mismatchedPixels / totalPixels;
}

({int minX, int minY, int maxX, int maxY})? nonBackgroundBoundingBox(
  Uint8List rgba,
  int width,
  int height, {
  int whiteThreshold = 250,
}) {
  int? minX;
  int? minY;
  int? maxX;
  int? maxY;

  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final a = rgba[i + 3];
      i += 4;

      // Treat fully transparent as background.
      if (a == 0) {
        continue;
      }

      // Background is white in these fixtures.
      final isBackground =
          r >= whiteThreshold && g >= whiteThreshold && b >= whiteThreshold;
      if (isBackground) {
        continue;
      }

      minX = minX == null ? x : math.min(minX, x);
      minY = minY == null ? y : math.min(minY, y);
      maxX = maxX == null ? x : math.max(maxX, x);
      maxY = maxY == null ? y : math.max(maxY, y);
    }
  }

  if (minX == null || minY == null || maxX == null || maxY == null) {
    return null;
  }
  return (minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

Uint8List _rgbaBytesFromImageBufferTopDown(ImageBuffer buffer) {
  // dart_graphics ImageBuffer stores rows top-down (row 0 = top).
  // Return a defensive copy so callers can safely slice/modify.
  return Uint8List.fromList(buffer.getBuffer());
}

Uint8List rgbaBytesFromImageBufferTopDown(ImageBuffer buffer) {
  return _rgbaBytesFromImageBufferTopDown(buffer);
}

img.Image decodePngFile(File file) {
  final bytes = file.readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    throw StateError('Failed to decode PNG: ${file.path}');
  }
  return decoded;
}

img.Image imageFromImageBufferTopDown(ImageBuffer buffer) {
  final w = buffer.width;
  final h = buffer.height;
  final rgba = _rgbaBytesFromImageBufferTopDown(buffer);

  final out = img.Image(width: w, height: h);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out.setPixelRgba(
        x,
        y,
        rgba[i],
        rgba[i + 1],
        rgba[i + 2],
        rgba[i + 3],
      );
      i += 4;
    }
  }
  return out;
}

GoldenDiff compareRgba({
  required ImageBuffer actual,
  required img.Image expected,
  int channelTolerance = 0,
}) {
  final w = expected.width;
  final h = expected.height;
  if (actual.width != w || actual.height != h) {
    return GoldenDiff(
      mismatchedPixels: w * h,
      totalPixels: w * h,
      firstMismatch: (x: 0, y: 0, expected: 0, actual: 0),
    );
  }

  final actualTopDown = _rgbaBytesFromImageBufferTopDown(actual);
  final expectedRgba = expected.getBytes(order: img.ChannelOrder.rgba);

  var mismatched = 0;
  ({int x, int y, int expected, int actual})? first;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;

      final er = expectedRgba[i];
      final eg = expectedRgba[i + 1];
      final eb = expectedRgba[i + 2];
      final ea = expectedRgba[i + 3];

      final ar = actualTopDown[i];
      final ag = actualTopDown[i + 1];
      final ab = actualTopDown[i + 2];
      final aa = actualTopDown[i + 3];

      final ok = (ar - er).abs() <= channelTolerance &&
          (ag - eg).abs() <= channelTolerance &&
          (ab - eb).abs() <= channelTolerance &&
          (aa - ea).abs() <= channelTolerance;

      if (!ok) {
        mismatched++;

        if (first == null) {
          final e = (er << 24) | (eg << 16) | (eb << 8) | ea;
          final a = (ar << 24) | (ag << 16) | (ab << 8) | aa;
          first = (x: x, y: y, expected: e, actual: a);
        }
      }
    }
  }

  return GoldenDiff(
    mismatchedPixels: mismatched,
    totalPixels: w * h,
    firstMismatch: first,
  );
}

img.Image createDiffImage({
  required ImageBuffer actual,
  required img.Image expected,
}) {
  final w = math.min(actual.width, expected.width);
  final h = math.min(actual.height, expected.height);

  final actualTopDown = _rgbaBytesFromImageBufferTopDown(actual);
  final expectedRgba = expected.getBytes(order: img.ChannelOrder.rgba);

  final diff = img.Image(width: w, height: h);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final er = expectedRgba[i];
      final eg = expectedRgba[i + 1];
      final eb = expectedRgba[i + 2];

      final ar = actualTopDown[i];
      final ag = actualTopDown[i + 1];
      final ab = actualTopDown[i + 2];

      final dr = (ar - er).abs();
      final dg = (ag - eg).abs();
      final db = (ab - eb).abs();

      // High-contrast diff visualization.
      diff.setPixelRgba(x, y, dr, dg, db, 255);
    }
  }

  return diff;
}

void writePng(img.Image image, File outFile) {
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(image));
}

void writeImageBufferPng(ImageBuffer buffer, File outFile) {
  writePng(imageFromImageBufferTopDown(buffer), outFile);
}


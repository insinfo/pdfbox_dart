import 'dart:typed_data';

/// Simple raster container used for colour space conversions.
///
/// Component values are stored as doubles in the range 0..1. The caller is
/// responsible for normalising raw sample data before construction.
class PDRaster {
  PDRaster({
    required this.width,
    required this.height,
    required this.componentsPerPixel,
    required List<double> samples,
  }) : _samples = List<double>.from(samples, growable: false) {
    final expected = width * height * componentsPerPixel;
    if (_samples.length != expected) {
      throw ArgumentError(
        'Expected $expected samples but received ${_samples.length}.',
      );
    }
  }

  /// Builds a raster from interleaved 8-bit component data.
  factory PDRaster.fromBytes({
    required int width,
    required int height,
    required int componentsPerPixel,
    required Uint8List bytes,
    int bitsPerComponent = 8,
  }) {
    if (bitsPerComponent != 8) {
      throw UnsupportedError(
        'Only 8-bit component rasters are supported (got $bitsPerComponent).',
      );
    }
    final expected = width * height * componentsPerPixel;
    if (bytes.length < expected) {
      throw ArgumentError(
        'Expected at least $expected bytes but received ${bytes.length}.',
      );
    }
    final samples = List<double>.generate(
      expected,
      (index) => bytes[index] / 255.0,
      growable: false,
    );
    return PDRaster(
      width: width,
      height: height,
      componentsPerPixel: componentsPerPixel,
      samples: samples,
    );
  }

  final int width;
  final int height;
  final int componentsPerPixel;
  final List<double> _samples;

  /// Returns a defensive copy of the underlying sample data.
  List<double> get samples => List<double>.from(_samples, growable: false);

  /// Copies the components of the pixel at [x], [y] into [destination].
  void getPixel(int x, int y, List<double> destination) {
    if (destination.length < componentsPerPixel) {
      throw ArgumentError(
        'Destination must contain at least $componentsPerPixel elements.',
      );
    }
    final base = _pixelOffset(x, y);
    for (var i = 0; i < componentsPerPixel; ++i) {
      destination[i] = _samples[base + i];
    }
  }

  /// Copies the pixel into [destination], scaling component values to 0..255.
  void getPixelBytes(int x, int y, List<int> destination) {
    if (destination.length < componentsPerPixel) {
      throw ArgumentError(
        'Destination must contain at least $componentsPerPixel elements.',
      );
    }
    final base = _pixelOffset(x, y);
    for (var i = 0; i < componentsPerPixel; ++i) {
      final scaled = (_samples[base + i] * 255.0).round();
      destination[i] = scaled.clamp(0, 255);
    }
  }

  int _pixelOffset(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      throw RangeError('Pixel ($x,$y) is outside the raster bounds.');
    }
    return (y * width + x) * componentsPerPixel;
  }
}

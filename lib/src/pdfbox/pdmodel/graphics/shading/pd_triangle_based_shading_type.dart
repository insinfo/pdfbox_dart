part of 'pd_shading.dart';

/// Common resources for shading types 4, 5, 6 and 7.
/// Port of PDFBox PDTriangleBasedShadingType.java
abstract class PDTriangleBasedShadingType extends PDShading {
  PDTriangleBasedShadingType(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  COSArray? _decode;
  int _bitsPerCoordinate = -1;
  int _bitsPerColorComponent = -1;
  int _numberOfColorComponents = -1;

  /// The bits per component of this shading.
  int get bitsPerComponent {
    if (_bitsPerColorComponent == -1) {
      _bitsPerColorComponent =
          cosObject.getInt(COSName.bitsPerComponent) ?? -1;
    }
    return _bitsPerColorComponent;
  }

  set bitsPerComponent(int value) {
    cosObject.setInt(COSName.bitsPerComponent, value);
    _bitsPerColorComponent = value;
  }

  /// The bits per coordinate of this shading.
  int get bitsPerCoordinate {
    if (_bitsPerCoordinate == -1) {
      _bitsPerCoordinate = cosObject.getInt(COSName.bitsPerCoordinate) ?? -1;
    }
    return _bitsPerCoordinate;
  }

  set bitsPerCoordinate(int value) {
    cosObject.setInt(COSName.bitsPerCoordinate, value);
    _bitsPerCoordinate = value;
  }

  /// The number of color components of this shading.
  int get numberOfColorComponents {
    if (_numberOfColorComponents == -1) {
      final fn = _getFunction();
      if (fn != null) {
        _numberOfColorComponents = 1;
      } else {
        final cs = colorSpace;
        _numberOfColorComponents = cs?.numberOfComponents ?? 1;
      }
    }
    return _numberOfColorComponents;
  }

  PDFunction? _getFunction() {
    final base = cosObject.getDictionaryObject(COSName.function);
    if (base == null) {
      return null;
    }
    return PDFunction.create(base);
  }

  /// Returns all decode values as COSArray.
  COSArray? get decodeValues =>
      _decode ??= cosObject.getCOSArray(COSName.decode);

  set decodeValues(COSArray? value) {
    _decode = value;
    if (value != null) {
      cosObject.setItem(COSName.decode, value);
    } else {
      cosObject.removeItem(COSName.decode);
    }
  }

  /// Get the decode for the input parameter.
  PDRange? getDecodeForParameter(int paramNum) {
    final decodeArray = decodeValues;
    if (decodeArray != null && decodeArray.length >= paramNum * 2 + 2) {
      return PDRange(decodeArray, paramNum);
    }
    return null;
  }

  /// Calculate the interpolation, see p.345 pdf spec 1.7.
  double interpolate(double src, int srcMax, double dstMin, double dstMax) {
    return dstMin + (src * (dstMax - dstMin) / srcMax);
  }

  /// Read a vertex from the bit input stream performs interpolations.
  ShadingVertex readVertex(
    BitInputStream input,
    int maxSrcCoord,
    int maxSrcColor,
    PDRange rangeX,
    PDRange rangeY,
    List<PDRange> colRangeTab,
    Matrix matrix,
    Affine xform,
  ) {
    if (bitsPerCoordinate <= 0 ||
        numberOfColorComponents <= 0 ||
        bitsPerComponent <= 0) {
      throw StateError(
          'Invalid bitsPerCoordinate, numberOfColorComponents or bitsPerColorComponent');
    }

    final colorComponentTab = List<double>.filled(numberOfColorComponents, 0);
    final x = input.readBits(bitsPerCoordinate);
    final y = input.readBits(bitsPerCoordinate);
    final dstX = interpolate(x.toDouble(), maxSrcCoord, rangeX.min, rangeX.max);
    final dstY = interpolate(y.toDouble(), maxSrcCoord, rangeY.min, rangeY.max);

    final p = matrix.transformPoint(dstX, dstY);
    final transformed = xform.transformPoint(p.x, p.y);

    for (var n = 0; n < numberOfColorComponents; n++) {
      final colorVal = input.readBits(bitsPerComponent);
      colorComponentTab[n] = interpolate(
          colorVal.toDouble(), maxSrcColor, colRangeTab[n].min, colRangeTab[n].max);
    }

    // "Each set of vertex data shall occupy a whole number of bytes..."
    final bitOffset = input.bitOffset;
    if (bitOffset != 0) {
      input.readBits(8 - bitOffset);
    }

    return ShadingVertex(Point(transformed.x, transformed.y), colorComponentTab);
  }

  /// Collect triangles for rendering.
  List<ShadedTriangle> collectTriangles(Affine xform, Matrix matrix);
}

/// A simple range helper class.
class PDRange {
  final COSArray _array;
  final int _startIndex;

  PDRange(this._array, int paramNum) : _startIndex = paramNum * 2;

  double get min => _array.getDouble(_startIndex) ?? 0.0;
  double get max => _array.getDouble(_startIndex + 1) ?? 1.0;
}

/// Bit input stream for reading mesh shading data.
class BitInputStream {
  final List<int> _data;
  int _byteOffset = 0;
  int _bitOffset = 0;

  BitInputStream(this._data);

  int get bitOffset => _bitOffset;

  int readBits(int numBits) {
    if (numBits <= 0) {
      return 0;
    }

    int result = 0;
    int bitsRemaining = numBits;

    while (bitsRemaining > 0) {
      if (_byteOffset >= _data.length) {
        throw StateError('Unexpected end of stream');
      }

      final bitsAvailable = 8 - _bitOffset;
      final bitsToRead =
          bitsRemaining < bitsAvailable ? bitsRemaining : bitsAvailable;

      final shift = bitsAvailable - bitsToRead;
      final mask = ((1 << bitsToRead) - 1) << shift;
      final bits = (_data[_byteOffset] & mask) >> shift;

      result = (result << bitsToRead) | bits;

      _bitOffset += bitsToRead;
      if (_bitOffset >= 8) {
        _bitOffset = 0;
        _byteOffset++;
      }

      bitsRemaining -= bitsToRead;
    }

    return result;
  }

  bool get isEof => _byteOffset >= _data.length;
}


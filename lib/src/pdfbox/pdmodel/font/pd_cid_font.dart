import 'dart:collection';
import 'dart:typed_data';

import '../../../fontbox/cff/char_string_path.dart';
import '../../../fontbox/util/bounding_box.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_number.dart';
import '../../cos/cos_stream.dart';
import '../../util/matrix.dart';
import '../../util/vector.dart';
import 'cid_system_info.dart';
import 'pd_font_descriptor.dart';
import 'pd_type0_font.dart';
import 'pdfont_like.dart';
import 'pd_vector_font.dart';

/// Base implementation for CID fonts referenced by Type 0 parents.
abstract class PDCIDFont implements PDFontLike, PDVectorFont {
  PDCIDFont(this.dict, this.parent) {
    _readWidths();
    _readVerticalDisplacements();
  }

  /// Raw CIDFont dictionary.
  final COSDictionary dict;

  /// Owning Type 0 font dictionary.
  final PDType0Font parent;

  final Map<int, double> _widths = HashMap<int, double>();
  double _defaultWidth = 0;
  double _averageWidth = 0;
  final Map<int, double> _verticalDisplacementY = HashMap<int, double>();
  final Map<int, Vector> _positionVectors = HashMap<int, Vector>();
  final List<double> _dw2 = <double>[880, -1000];
  PDFontDescriptor? _fontDescriptor;

  /// Returns the descendant font dictionary as a [COSDictionary].
  COSDictionary get cosObject => dict;

  /// Returns the PostScript base font name.
  String? getBaseFont() => dict.getNameAsString(COSName.baseFont);

  @override
  String? getName() => getBaseFont();

  @override
  PDFontDescriptor? getFontDescriptor() {
    final cached = _fontDescriptor;
    if (cached != null) {
      return cached;
    }
    final descriptorDict = dict.getCOSDictionary(COSName.fontDescriptor);
    if (descriptorDict == null) {
      return null;
    }
    final descriptor = PDFontDescriptor(descriptorDict);
    _fontDescriptor = descriptor;
    return descriptor;
  }

  /// Returns the enclosing Type 0 font.
  PDType0Font getParent() => parent;

  double _getDefaultWidth() {
    if (_defaultWidth == 0) {
      final base = dict.getDictionaryObject(COSName.dw);
      if (base is COSNumber) {
        _defaultWidth = base.doubleValue;
      } else {
        _defaultWidth = 1000;
      }
    }
    return _defaultWidth;
  }

  double _getWidthForCid(int cid) => _widths[cid] ?? _getDefaultWidth();

  Vector _getDefaultPositionVector(int cid) => Vector(_getWidthForCid(cid) / 2, _dw2[0]);

  /// Returns the CIDSystemInfo entry when present.
  CidSystemInfo? get cidSystemInfo {
    final info = dict.getCOSDictionary(COSName.cidSystemInfo);
    if (info == null) {
      return null;
    }
    final registry = info.getString(COSName.registry);
    final ordering = info.getString(COSName.ordering);
    final supplement = info.getInt(COSName.supplement);
    if (registry == null || ordering == null || supplement == null) {
      return null;
    }
    return CidSystemInfo(
      registry: registry,
      ordering: ordering,
      supplement: supplement,
    );
  }

  @override
  bool hasExplicitWidth(int code) => _widths.containsKey(codeToCID(code));

  @override
  Vector getPositionVector(int code) {
    final cid = codeToCID(code);
    final vector = _positionVectors[cid];
    if (vector != null) {
      return vector;
    }
    final fallback = _getDefaultPositionVector(cid);
    _positionVectors[cid] = fallback;
    return fallback;
  }

  /// Returns the vertical displacement Y component for [code].
  double getVerticalDisplacementVectorY(int code) {
    final cid = codeToCID(code);
    final value = _verticalDisplacementY[cid];
    return value ?? _dw2[1];
  }

  @override
  double getWidth(int code) => _getWidthForCid(codeToCID(code));

  @override
  double getAverageFontWidth() {
    if (_averageWidth == 0) {
      var total = 0.0;
      var count = 0;
      for (final width in _widths.values) {
        if (width > 0) {
          total += width;
          count++;
        }
      }
      if (count > 0) {
        _averageWidth = total / count;
      }
      if (_averageWidth <= 0 || _averageWidth.isNaN) {
        _averageWidth = _getDefaultWidth();
      }
    }
    return _averageWidth;
  }

  /// Reads the descendant font bounding box.
  BoundingBox? get cidFontBoundingBox;

  /// Reads the native font matrix.
  List<num>? get cidFontMatrix;

  @override
  Matrix getFontMatrix();

  @override
  BoundingBox getBoundingBox();

  @override
  double getHeight(int code);

  @override
  double getWidthFromFont(int code);

  @override
  bool isEmbedded();

  @override
  bool isDamaged();

  @override
  CharStringPath getPath(int code);

  @override
  CharStringPath getNormalizedPath(int code);

  @override
  bool hasGlyph(int code);

  /// Resolves the CID for a given encoded character code.
  int codeToCID(int code);

  /// Resolves the glyph identifier for a given encoded character code.
  int codeToGID(int code);

  /// Encodes the glyph id into bytes suitable for CIDToGID streams.
  Uint8List encodeGlyphId(int glyphId);

  /// Encodes the provided Unicode code point into PDF content bytes.
  Uint8List encode(int unicode);

  /// Extracts the raw CID-to-GID mapping when present.
  List<int>? readCidToGidMap() {
    final base = dict.getDictionaryObject(COSName.cidToGidMap);
    if (base is COSName) {
      return null;
    }
    if (base is COSStream) {
      final bytes = base.decode();
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final length = bytes.length ~/ 2;
      final mapping = List<int>.filled(length, 0, growable: false);
      var offset = 0;
      for (var index = 0; index < length; index++) {
        final high = bytes[offset] & 0xff;
        final low = bytes[offset + 1] & 0xff;
        mapping[index] = (high << 8) | low;
        offset += 2;
      }
      return mapping;
    }
    return null;
  }

  void _readWidths() {
    final wArray = dict.getCOSArray(COSName.w);
    if (wArray == null || wArray.length < 2) {
      return;
    }
    var index = 0;
    while (index < wArray.length - 1) {
      final firstCodeObj = wArray.getObject(index++);
      if (firstCodeObj is! COSNumber) {
        continue;
      }
      final firstCode = firstCodeObj.intValue;
      final next = wArray.getObject(index++);
      if (next is COSArray) {
        for (var arrayIndex = 0; arrayIndex < next.length; arrayIndex++) {
          final widthObj = next.getObject(arrayIndex);
          if (widthObj is COSNumber) {
            _widths[firstCode + arrayIndex] = widthObj.doubleValue;
          }
        }
      } else {
        if (index >= wArray.length) {
          break;
        }
        final secondCodeObj = next;
        final rangeWidthObj = wArray.getObject(index++);
        if (secondCodeObj is COSNumber && rangeWidthObj is COSNumber) {
          final start = firstCode;
          final end = secondCodeObj.intValue;
          final width = rangeWidthObj.doubleValue;
          for (var cid = start; cid <= end; cid++) {
            _widths[cid] = width;
          }
        }
      }
    }
  }

  void _readVerticalDisplacements() {
    final dw2Array = dict.getCOSArray(COSName.dw2);
    if (dw2Array != null && dw2Array.length >= 2) {
      final x = dw2Array.getObject(0);
      final y = dw2Array.getObject(1);
      if (x is COSNumber && y is COSNumber) {
        _dw2[0] = x.doubleValue;
        _dw2[1] = y.doubleValue;
      }
    }

    final w2Array = dict.getCOSArray(COSName.w2);
    if (w2Array == null || w2Array.length < 4) {
      return;
    }
    var index = 0;
    while (index < w2Array.length) {
      final base = w2Array.getObject(index++);
      if (base is! COSNumber) {
        continue;
      }
      final first = base.intValue;
      final next = w2Array.getObject(index++);
      if (next is COSArray) {
        var j = 0;
        while (j + 2 < next.length) {
          final cid = first + j ~/ 3;
          final w1yObj = next.getObject(j++);
          final v1xObj = next.getObject(j++);
          final v1yObj = next.getObject(j++);
          if (w1yObj is COSNumber && v1xObj is COSNumber && v1yObj is COSNumber) {
            _verticalDisplacementY[cid] = w1yObj.doubleValue;
            _positionVectors[cid] = Vector(v1xObj.doubleValue, v1yObj.doubleValue);
          }
        }
      } else {
        if (index + 2 >= w2Array.length) {
          break;
        }
        final secondObj = next;
        final w1yObj = w2Array.getObject(index++);
        final v1xObj = w2Array.getObject(index++);
        final v1yObj = w2Array.getObject(index++);
        if (secondObj is COSNumber && w1yObj is COSNumber &&
            v1xObj is COSNumber && v1yObj is COSNumber) {
          final start = first;
          final end = secondObj.intValue;
          final w1y = w1yObj.doubleValue;
          final v1x = v1xObj.doubleValue;
          final v1y = v1yObj.doubleValue;
          for (var cid = start; cid <= end; cid++) {
            _verticalDisplacementY[cid] = w1y;
            _positionVectors[cid] = Vector(v1x, v1y);
          }
        }
      }
    }
  }
}

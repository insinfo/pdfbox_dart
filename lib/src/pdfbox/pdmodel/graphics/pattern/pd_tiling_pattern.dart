import '../../../cos/cos_array.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../util/matrix.dart';
import '../../common/pd_rectangle.dart';
import '../../pd_resources.dart';
import '../../pd_stream.dart';
import 'pd_abstract_pattern.dart';

/// Pattern type 1 – tiling pattern.
///
/// Port of PDFBox's `PDTilingPattern`.
class PDTilingPattern extends PDAbstractPattern {
  PDTilingPattern(COSStream stream, {PDResources? resources})
      : _stream = PDStream(stream),
        super(stream, resources: resources);

  final PDStream _stream;

  PDStream get contentStream => _stream;

  /// 1 = coloured, 2 = uncoloured.
  int get paintType => cosObject.getInt(COSName.paintType) ?? 0;
  set paintType(int value) => cosObject.setInt(COSName.paintType, value);

  /// 1..3 (see PDF spec). Currently informational.
  int get tilingType => cosObject.getInt(COSName.tilingType) ?? 0;
  set tilingType(int value) => cosObject.setInt(COSName.tilingType, value);

  PDRectangle? get boundingBox {
    final array = cosObject.getCOSArray(COSName.bBox);
    if (array == null) {
      return null;
    }
    return PDRectangle.fromCOSArray(array);
  }
  set boundingBox(PDRectangle? value) {
    if (value == null) {
      cosObject.removeItem(COSName.bBox);
    } else {
      cosObject[COSName.bBox] = value.toCOSArray();
    }
  }

  double get xStep => cosObject.getFloat(COSName.xStep) ?? 0.0;
  set xStep(double value) => cosObject.setFloat(COSName.xStep, value);

  double get yStep => cosObject.getFloat(COSName.yStep) ?? 0.0;
  set yStep(double value) => cosObject.setFloat(COSName.yStep, value);

  Matrix get matrix {
    final array = cosObject.getCOSArray(COSName.matrix);
    if (array == null) {
      return Matrix();
    }
    return Matrix.fromCos(array);
  }
  set matrix(Matrix value) {
    final components = value.toList();
    final cosArray = COSArray()
      ..add(COSFloat(components[0]))
      ..add(COSFloat(components[1]))
      ..add(COSFloat(components[3]))
      ..add(COSFloat(components[4]))
      ..add(COSFloat(components[6]))
      ..add(COSFloat(components[7]));
    cosObject[COSName.matrix] = cosArray;
  }

  PDResources? get patternResources {
    final dict = cosObject.getCOSDictionary(COSName.resources);
    if (dict == null) {
      return null;
    }
    return PDResources(dict, resources?.resourceCache);
  }
  set patternResources(PDResources? value) {
    if (value == null) {
      cosObject.removeItem(COSName.resources);
    } else {
      cosObject[COSName.resources] = value.cosObject;
    }
  }
}


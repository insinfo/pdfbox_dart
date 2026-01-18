import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../util/matrix.dart';
import '../../common/pd_rectangle.dart';
import '../../pd_resources.dart';
import '../../pd_stream.dart';
import 'pd_abstract_pattern.dart';

/// Pattern type 1 – tiling pattern.
///
/// Port of PDFBox's `PDTilingPattern` TODO minimal depois tem concluir o porte completo.
class PDTilingPattern extends PDAbstractPattern {
  PDTilingPattern(COSStream stream, {PDResources? resources})
      : _stream = PDStream(stream),
        super(stream, resources: resources);

  final PDStream _stream;

  PDStream get contentStream => _stream;

  /// 1 = coloured, 2 = uncoloured.
  int get paintType => cosObject.getInt(COSName.paintType) ?? 0;

  /// 1..3 (see PDF spec). Currently informational.
  int get tilingType => cosObject.getInt(COSName.tilingType) ?? 0;

  PDRectangle? get boundingBox {
    final array = cosObject.getCOSArray(COSName.bBox);
    if (array == null) {
      return null;
    }
    return PDRectangle.fromCOSArray(array);
  }

  double get xStep => cosObject.getFloat(COSName.xStep) ?? 0.0;

  double get yStep => cosObject.getFloat(COSName.yStep) ?? 0.0;

  Matrix get matrix {
    final array = cosObject.getCOSArray(COSName.matrix);
    if (array == null) {
      return Matrix();
    }
    return Matrix.fromCos(array);
  }

  PDResources? get patternResources {
    final dict = cosObject.getCOSDictionary(COSName.resources);
    if (dict == null) {
      return null;
    }
    return PDResources(dict, resources?.resourceCache);
  }
}

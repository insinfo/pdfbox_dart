import '../../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../util/matrix.dart';

/// Minimal representation of a soft mask dictionary.
class PDSoftMask implements COSObjectable {
  PDSoftMask(this.dictionary);

  /// Creates a soft mask from a raw COS value following PDFBox semantics.
  static PDSoftMask? create(COSBase? base) {
    if (base == null) {
      return null;
    }
    if (base is COSName && base.name == 'None') {
      return null;
    }
    if (base is COSDictionary) {
      return PDSoftMask(base);
    }
    return null;
  }

  final COSDictionary dictionary;
  Matrix? _initialTransformationMatrix;

  @override
  COSDictionary get cosObject => dictionary;

  /// Stores the CTM active when the graphics state is applied.
  void setInitialTransformationMatrix(Matrix matrix) {
    _initialTransformationMatrix = matrix.clone();
  }

  /// Returns the saved CTM if any.
  Matrix? getInitialTransformationMatrix() =>
      _initialTransformationMatrix?.clone();
}

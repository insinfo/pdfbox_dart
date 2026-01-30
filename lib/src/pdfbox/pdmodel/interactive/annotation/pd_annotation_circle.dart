import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'handlers/pd_circle_appearance_handler.dart';
import 'pd_annotation_square_circle.dart';

/// This is the class that represents a circle annotation.
class PDAnnotationCircle extends PDAnnotationSquareCircle {
  /// The type of annotation.
  static const String subType = 'Circle';

  /// Creates a circle annotation from a COSDictionary.
  PDAnnotationCircle(COSDictionary field) : super(field);

  /// Creates a nice new circle annotation.
  PDAnnotationCircle.create() : super.create(subType);

  @override
  void constructAppearances([PDDocument? document]) {
    if (getCustomAppearanceHandler() == null) {
      PDCircleAppearanceHandler(this, document).generateAppearanceStreams();
    } else {
      getCustomAppearanceHandler()?.generateAppearanceStreams();
    }
  }
}

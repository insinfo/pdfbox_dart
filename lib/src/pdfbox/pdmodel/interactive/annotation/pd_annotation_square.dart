import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'pd_annotation_square_circle.dart';

/// This is the class that represents a rectangular annotation.
class PDAnnotationSquare extends PDAnnotationSquareCircle {
  /// The type of annotation.
  static const String subType = 'Square';

  /// Creates a square annotation from a COSDictionary.
  PDAnnotationSquare(COSDictionary field) : super(field);

  /// Creates a nice new square annotation.
  PDAnnotationSquare.create() : super.create(subType);

  @override
  void constructAppearances([PDDocument? document]) {
    // TODO: Implement appearance generation using PDSquareAppearanceHandler
    // if (customAppearanceHandler == null) {
    //   PDSquareAppearanceHandler(this, document).generateAppearanceStreams();
    // } else {
    //   customAppearanceHandler.generateAppearanceStreams();
    // }
  }
}

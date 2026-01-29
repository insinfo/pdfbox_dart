import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'pd_annotation_text_markup.dart';

/// This is the class that represents a Squiggly annotation.
class PDAnnotationSquiggly extends PDAnnotationTextMarkup {
  /// The type of annotation.
  static const String subType = 'Squiggly';

  /// Constructor.
  PDAnnotationSquiggly([COSDictionary? dict]) : super(subType, dict);

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDSquigglyAppearanceHandler logic when handlers are ported
  }
}

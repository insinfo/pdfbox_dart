import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'pd_annotation_text_markup.dart';

/// This is the class that represents a Highlight annotation.
class PDAnnotationHighlight extends PDAnnotationTextMarkup {
  /// The type of annotation.
  static const String subType = 'Highlight';

  /// Constructor.
  PDAnnotationHighlight([COSDictionary? dict]) : super(subType, dict);

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDHighlightAppearanceHandler logic when handlers are ported
  }
}

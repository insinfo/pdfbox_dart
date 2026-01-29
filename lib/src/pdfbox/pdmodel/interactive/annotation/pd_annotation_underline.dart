import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'pd_annotation_text_markup.dart';

/// This is the class that represents a Underline annotation.
class PDAnnotationUnderline extends PDAnnotationTextMarkup {
  /// The type of annotation.
  static const String subType = 'Underline';

  /// Constructor.
  PDAnnotationUnderline([COSDictionary? dict]) : super(subType, dict);

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDUnderlineAppearanceHandler logic when handlers are ported
  }
}

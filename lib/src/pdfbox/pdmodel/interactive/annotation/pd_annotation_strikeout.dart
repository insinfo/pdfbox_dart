import '../../../cos/cos_dictionary.dart';
import '../../pd_document.dart';
import 'pd_annotation_text_markup.dart';

/// This is the class that represents a Strikeout annotation.
class PDAnnotationStrikeout extends PDAnnotationTextMarkup {
  /// The type of annotation.
  static const String subType = 'StrikeOut';

  /// Constructor.
  PDAnnotationStrikeout([COSDictionary? dict]) : super(subType, dict);

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDStrikeoutAppearanceHandler logic when handlers are ported
  }
}

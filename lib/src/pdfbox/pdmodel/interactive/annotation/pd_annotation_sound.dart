import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a Sound annotation.
class PDAnnotationSound extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'Sound';

  /// Constructor.
  PDAnnotationSound([COSDictionary? field]) : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDSoundAppearanceHandler logic when handlers are ported
  }
}

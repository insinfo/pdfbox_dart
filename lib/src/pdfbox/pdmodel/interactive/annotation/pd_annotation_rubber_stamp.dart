import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a rubber stamp annotation. Introduced in PDF 1.3 specification
class PDAnnotationRubberStamp extends PDAnnotationMarkup {
  /// Constant for the name of a rubber stamp.
  static const String nameApproved = 'Approved';

  /// Constant for the name of a rubber stamp.
  static const String nameExperimental = 'Experimental';

  /// Constant for the name of a rubber stamp.
  static const String nameNotApproved = 'NotApproved';

  /// Constant for the name of a rubber stamp.
  static const String nameAsIs = 'AsIs';

  /// Constant for the name of a rubber stamp.
  static const String nameExpired = 'Expired';

  /// Constant for the name of a rubber stamp.
  static const String nameNotForPublicRelease = 'NotForPublicRelease';

  /// Constant for the name of a rubber stamp.
  static const String nameForPublicRelease = 'ForPublicRelease';

  /// Constant for the name of a rubber stamp.
  static const String nameDraft = 'Draft';

  /// Constant for the name of a rubber stamp.
  static const String nameForComment = 'ForComment';

  /// Constant for the name of a rubber stamp.
  static const String nameTopSecret = 'TopSecret';

  /// Constant for the name of a rubber stamp.
  static const String nameDepartmental = 'Departmental';

  /// Constant for the name of a rubber stamp.
  static const String nameConfidential = 'Confidential';

  /// Constant for the name of a rubber stamp.
  static const String nameFinal = 'Final';

  /// Constant for the name of a rubber stamp.
  static const String nameSold = 'Sold';

  /// The type of annotation.
  static const String subType = 'Stamp';

  /// Constructor.
  PDAnnotationRubberStamp([COSDictionary? field])
      : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// This will set the name (and hence appearance, AP taking precedence) For this annotation. See the NAME_XXX
  /// constants for valid values.
  void setName(String name) {
    dictionary.setName(COSName.nameKey, name);
  }

  /// This will retrieve the name (and hence appearance, AP taking precedence) For this annotation. The default is
  /// DRAFT.
  ///
  /// Returns The name of this rubber stamp.
  String getName() {
    return dictionary.getNameAsString(COSName.nameKey, nameDraft) ?? nameDraft;
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDAnnotationRubberStamp logic when handlers are ported
  }
}

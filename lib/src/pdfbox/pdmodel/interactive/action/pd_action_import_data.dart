import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_file_specification.dart';

import 'pd_action.dart';

/// This represents an ImportData action that can be executed in a PDF document.
class PDActionImportData extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'ImportData';

  /// Default constructor.
  PDActionImportData() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionImportData.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// This will get the file in which the destination is located.
  ///
  /// @return The F entry of the specific ImportData action dictionary.
  PDFileSpecification? getFile() {
    return PDFileSpecification.createFS(action.getDictionaryObject(COSName.f));
  }

  /// This will set the file in which the destination is located.
  ///
  /// @param fs The file specification.
  void setFile(PDFileSpecification? fs) {
    action.setItem(COSName.f, fs);
  }
}

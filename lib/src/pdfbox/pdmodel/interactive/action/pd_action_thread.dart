import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_file_specification.dart';

import 'pd_action.dart';

/// This represents a thread action that can be executed in a PDF document.
class PDActionThread extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'Thread';

  /// Default constructor.
  PDActionThread() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionThread.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Gets the D entry of the specific thread action dictionary.
  ///
  /// @return The D entry (Dictionary, Integer or String).
  COSBase? getD() {
    return action.getDictionaryObject(COSName.d);
  }

  /// Sets the destination.
  ///
  /// @param d The destination.
  void setD(COSBase? d) {
    action.setItem(COSName.d, d);
  }

  /// This will get the file in which the destination is located.
  ///
  /// @return The F entry of the specific thread action dictionary.
  PDFileSpecification? getFile() {
    return PDFileSpecification.createFS(action.getDictionaryObject(COSName.f));
  }

  /// This will set the file in which the destination is located.
  ///
  /// @param fs The file specification.
  void setFile(PDFileSpecification? fs) {
    action.setItem(COSName.f, fs);
  }

  /// Gets the B entry of the specific thread action dictionary.
  ///
  /// @return The B entry (Dictionary or Integer).
  COSBase? getB() {
    return action.getDictionaryObject(COSName.b);
  }

  /// Sets the B entry.
  ///
  /// @param b The bead entry.
  void setB(COSBase? b) {
    action.setItem(COSName.b, b);
  }
}

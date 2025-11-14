import '../../../cos/cos_dictionary.dart';
import 'pd_action.dart';

/// Fallback wrapper for unrecognized action subtypes.
class PDActionUnknown extends PDAction {
  PDActionUnknown(COSDictionary dictionary) : super(dictionary);

  /// Returns the subtype recorded in the wrapped dictionary, if any.
  String? get recordedSubtype => subtype;
}

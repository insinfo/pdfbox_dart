import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_action.dart';
import 'pd_action_go_to.dart';
import 'pd_action_java_script.dart';
import 'pd_action_launch.dart';
import 'pd_action_named.dart';
import 'pd_action_remote_go_to.dart';
import 'pd_action_unknown.dart';
import 'pd_action_uri.dart';

/// Utility that chooses the appropriate [PDAction] wrapper for a dictionary.
class PDActionFactory {
  const PDActionFactory._();

  static const PDActionFactory instance = PDActionFactory._();

  /// Returns a typed action wrapper for the given COS representation.
  PDAction? createAction(COSBase? base) {
    final dictionary = PDAction.dictionaryFrom(base);
    if (dictionary == null) {
      return null;
    }
    return createFromDictionary(dictionary);
  }

  /// Returns a typed action wrapper given a dictionary that is already known
  /// to be an action. This mirrors the Java `PDActionFactory` behaviour.
  PDAction createFromDictionary(COSDictionary dictionary) {
    final subtype = dictionary.getNameAsString(COSName.s);
    switch (subtype) {
      case null:
      case 'GoTo':
        return PDActionGoTo(dictionary: dictionary);
      case 'GoToR':
        return PDActionRemoteGoTo(dictionary: dictionary);
      case 'Launch':
        return PDActionLaunch(dictionary: dictionary);
      case 'JavaScript':
        return PDActionJavaScript(dictionary: dictionary);
      case 'URI':
        return PDActionURI(dictionary: dictionary);
      case 'Named':
        return PDActionNamed(dictionary: dictionary);
      default:
        return PDActionUnknown(dictionary);
    }
  }
}

import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_action.dart';
import 'pd_action_go_to.dart';
import 'pd_action_hide.dart';
import 'pd_action_import_data.dart';
import 'pd_action_java_script.dart';
import 'pd_action_launch.dart';
import 'pd_action_movie.dart';
import 'pd_action_named.dart';
import 'pd_action_remote_go_to.dart';
import 'pd_action_reset_form.dart';
import 'pd_action_sound.dart';
import 'pd_action_submit_form.dart';
import 'pd_action_thread.dart';
import 'pd_action_unknown.dart';
import 'pd_action_uri.dart';

/// Utility that chooses the appropriate [PDAction] wrapper for a dictionary.
class PDActionFactory {
  const PDActionFactory._();

  static const PDActionFactory instance = PDActionFactory._();

  /// Returns a typed action wrapper for the given COS representation.
  PDAction? createAction(COSBase? base) {
    if (base is COSDictionary) {
      return createFromDictionary(base);
    }
    return null;
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
      case 'Hide':
        return PDActionHide.fromDictionary(dictionary);
      case 'ImportData':
        return PDActionImportData.fromDictionary(dictionary);
      case 'Movie':
        return PDActionMovie.fromDictionary(dictionary);
      case 'ResetForm':
        return PDActionResetForm.fromDictionary(dictionary);
      case 'Sound':
        return PDActionSound.fromDictionary(dictionary);
      case 'SubmitForm':
        return PDActionSubmitForm.fromDictionary(dictionary);
      case 'Thread':
        return PDActionThread.fromDictionary(dictionary);
      default:
        return PDActionUnknown(dictionary);
    }
  }
}

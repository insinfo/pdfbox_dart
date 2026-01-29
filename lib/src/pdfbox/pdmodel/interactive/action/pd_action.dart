import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../common/pd_destination_or_action.dart';
import 'pd_action_factory.dart';

/// This represents an action that can be executed in a PDF document.
abstract class PDAction implements PDDestinationOrAction {
  /// The type of PDF object.
  static const String type = 'Action';

  /// Default constructor.
  PDAction([COSDictionary? action]) : dictionary = action ?? COSDictionary() {
    if (action == null) {
      setType(type);
    }
  }

  static COSDictionary? dictionaryFrom(COSBase? base) {
    if (base == null) {
      return null;
    }
    if (base is COSDictionary) {
      return base;
    }
    if (base is COSObject) {
      final target = base.object;
      return target is COSDictionary ? target : null;
    }
    return null;
  }

  /// The action dictionary.
  final COSDictionary dictionary;

  @override
  COSDictionary get cosObject => dictionary;

  // Helper methods for subclasses
  COSBase? getDictionaryObject(COSName name) =>
      dictionary.getDictionaryObject(name);

  COSDictionary? getCOSDictionary(COSName name) =>
      dictionary.getCOSDictionary(name);

  void setItem(COSName name, COSObjectable? value) =>
      dictionary.setItem(name, value);

  bool? getBoolean(COSName name, [bool? defaultValue]) =>
      dictionary.getBoolean(name, defaultValue);

  void setBoolean(COSName name, bool value) =>
      dictionary.setBoolean(name, value);

  void removeItem(COSName name) => dictionary.removeItem(name);

  String? get subtype => getSubType();
  set subtype(String? value) {
    if (value != null) {
      setSubType(value);
    }
  }

  /// This will get the type of PDF object that the actions dictionary describes.
  /// If present must be Action for an action dictionary.
  String? getType() {
    return dictionary.getNameAsString(COSName.type);
  }

  /// This will set the type of PDF object that the actions dictionary describes.
  /// If present must be Action for an action dictionary.
  void setType(String type) {
    dictionary.setName(COSName.type, type);
  }

  /// This will get the type of action that the actions dictionary describes.
  String? getSubType() {
    return dictionary.getNameAsString(COSName.s);
  }

  /// This will set the type of action that the actions dictionary describes.
  void setSubType(String s) {
    dictionary.setName(COSName.s, s);
  }

  /// This will get the next action, or sequence of actions, to be performed after this one.
  /// The value is either a single action dictionary or an array of action dictionaries
  /// to be performed in order.
  List<PDAction> getNext() {
    final next = dictionary.getDictionaryObject(COSName.next);
    final result = <PDAction>[];

    if (next is COSDictionary) {
      final pdAction = PDActionFactory.instance.createFromDictionary(next);
      result.add(pdAction);
    } else if (next is COSArray) {
      for (var i = 0; i < next.length; i++) {
        final object = next.getObject(i);
        if (object is COSDictionary) {
          result.add(PDActionFactory.instance.createFromDictionary(object));
        }
      }
    }
    return result;
  }

  /// This will set the next action, or sequence of actions, to be performed after this one.
  /// The value is either a single action dictionary or an array of action dictionaries
  /// to be performed in order.
  void setNext(List<PDAction> next) {
    dictionary.setItem(
        COSName.next, COSArray(next.map((e) => e.cosObject).toList()));
  }
}

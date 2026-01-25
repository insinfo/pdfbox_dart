import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation.dart';

/// Text annotation (sticky note) wrapper.
class PDAnnotationText extends PDAnnotation {
  static const String NAME_COMMENT = "Comment";
  static const String NAME_KEY = "Key";
  static const String NAME_NOTE = "Note";
  static const String NAME_HELP = "Help";
  static const String NAME_NEW_PARAGRAPH = "NewParagraph";
  static const String NAME_PARAGRAPH = "Paragraph";
  static const String NAME_INSERT = "Insert";
  static const String NAME_CROSS = "Cross";
  static const String NAME_CIRCLE = "Circle";
  static const String NAME_CHECK = "Check";
  static const String NAME_STAR = "Star";

  PDAnnotationText.fromDictionary(COSDictionary dictionary)
      : super.internal(dictionary);

  bool get isOpen => dictionary.getBoolean(COSName.open) ?? false;

  set isOpen(bool value) => dictionary.setBoolean(COSName.open, value);

  String? get iconName => dictionary.getNameAsString(COSName.nameKey);

  set iconName(String? value) => dictionary.setName(COSName.nameKey, value);

  String? get state => dictionary.getString(COSName.state);

  set state(String? value) => dictionary.setString(COSName.state, value);

  String? get stateModel => dictionary.getString(COSName.stateModel);

  set stateModel(String? value) => dictionary.setString(COSName.stateModel, value);
}

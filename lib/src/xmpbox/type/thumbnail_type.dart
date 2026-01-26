import '../xmp_constants.dart';
import 'abstract_structured_type.dart';

/// XMP thumbnail structured type (xmpGImg).
/// Ported from org.apache.xmpbox.type.ThumbnailType
class ThumbnailType extends AbstractStructuredType {
  static const String defaultPrefix = 'xmpGImg';
  static const String defaultNamespace =
      'http://ns.adobe.com/xap/1.0/g/img/';

  static const String format = 'format';
  static const String width = 'width';
  static const String height = 'height';
  static const String image = 'image';

  ThumbnailType(dynamic metadata)
      : super.full(metadata, defaultNamespace, defaultPrefix, XmpConstants.listName);

  void setFormat(String value) => addSimpleProperty(format, value);

  void setWidth(int value) => addSimpleProperty(width, value);

  void setHeight(int value) => addSimpleProperty(height, value);

  void setImage(String value) => addSimpleProperty(image, value);

  String? getFormat() => getPropertyValueAsString(format);

  int? getWidth() => _getIntValue(width);

  int? getHeight() => _getIntValue(height);

  String? getImage() => getPropertyValueAsString(image);

  int? _getIntValue(String fieldName) {
    final value = getPropertyValueAsString(fieldName);
    if (value == null) return null;
    return int.tryParse(value);
  }
}

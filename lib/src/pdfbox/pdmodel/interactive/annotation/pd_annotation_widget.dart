import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation.dart';
import 'pd_annotation_appearance_characteristics.dart';

/// Widget annotation used by AcroForm fields.
class PDAnnotationWidget extends PDAnnotation {
  PDAnnotationWidget.fromDictionary(COSDictionary dictionary)
      : super.internal(dictionary);

  PDAppearanceCharacteristicsDictionary? _appearanceCharacteristicsCache;

  String? get highlightingMode => dictionary.getNameAsString(COSName.h);

  set highlightingMode(String? value) => dictionary.setName(COSName.h, value);

  String? get defaultAppearance =>
      dictionary.getString(COSName.defaultAppearance);

  set defaultAppearance(String? value) =>
      dictionary.setString(COSName.defaultAppearance, value);

  String? get defaultStyle => dictionary.getString(COSName.ds);

  set defaultStyle(String? value) => dictionary.setString(COSName.ds, value);

  PDAppearanceCharacteristicsDictionary? get appearanceCharacteristics {
    final cached = _appearanceCharacteristicsCache;
    if (cached != null) {
      return cached;
    }
    final dict = dictionary.getCOSDictionary(COSName.appearanceCharacteristics);
    if (dict == null) {
      return null;
    }
    final characteristics = PDAppearanceCharacteristicsDictionary(dict);
    _appearanceCharacteristicsCache = characteristics;
    return characteristics;
  }

  set appearanceCharacteristics(
    PDAppearanceCharacteristicsDictionary? value,
  ) {
    _appearanceCharacteristicsCache = value;
    if (value == null) {
      dictionary.removeItem(COSName.appearanceCharacteristics);
    } else {
      dictionary.setItem(COSName.appearanceCharacteristics, value.cosObject);
    }
  }
}

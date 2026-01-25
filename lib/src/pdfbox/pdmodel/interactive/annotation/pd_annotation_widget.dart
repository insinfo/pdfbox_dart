import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation.dart';
import 'pd_appearance_characteristics_dictionary.dart';
import '../action/pd_action.dart';
import '../action/pd_action_factory.dart';
import '../action/pd_annotation_additional_actions.dart';

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

  PDAction? get action {
    COSDictionary? action = dictionary.getCOSDictionary(COSName.a);
    return action != null ? PDActionFactory.instance.createAction(action) : null;
  }

  set action(PDAction? action) {
    dictionary.setItem(COSName.a, action);
  }

  PDAnnotationAdditionalActions? get actions {
    COSDictionary? actions = dictionary.getCOSDictionary(COSName.aa);
    return actions != null ? PDAnnotationAdditionalActions(actions) : null;
  }

  set actions(PDAnnotationAdditionalActions? actions) {
    dictionary.setItem(COSName.aa, actions);
  }
}


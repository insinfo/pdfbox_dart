import 'appearance_generator_helper.dart';
import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';
import '../annotation/pd_annotation_widget.dart';
import 'pd_acro_form.dart';
import 'pd_field.dart';
import 'pd_non_terminal_field.dart';

/// A field that contains a value.
abstract class PDTerminalField extends PDField {
  PDTerminalField(PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  @override
  List<PDAnnotationWidget> getWidgets() {
    final widgets = <PDAnnotationWidget>[];
    final kids = cosObject.getCOSArray(COSName.kids);
    if (kids == null) {
      // the field itself is a widget
      widgets.add(PDAnnotationWidget.fromDictionary(cosObject));
    } else if (kids.isNotEmpty) {
      // there are multiple widgets
      for (var i = 0; i < kids.length; i++) {
        final kid = kids.getObject(i);
        if (kid is COSDictionary) {
          widgets.add(PDAnnotationWidget.fromDictionary(kid));
        }
      }
    }
    return widgets;
  }

  /// Sets the field's widget annotations.
  void setWidgets(List<PDAnnotationWidget> children) {
    final kidsArray = COSArray();
    for (final widget in children) {
      kidsArray.add(widget.cosObject);
      widget.cosObject.setItem(COSName.parent, this);
    }
    cosObject.setItem(COSName.kids, kidsArray);
  }

  /// Constructs the appearance of the field.
  void constructAppearances() {
    final value = cosValue;
    if (value != null) {
        String stringValue;
        if (value is COSString) {
            stringValue = value.string;
        } else if (value is COSName) {
            stringValue = value.name;
        } else {
            stringValue = value.toString();
        }
        AppearanceGeneratorHelper(this).setAppearanceValue(stringValue);
    }
  }

  @override
  void setValue(String value) {
    super.setValue(value);
    constructAppearances();
  }
}

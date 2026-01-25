import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../annotation/pd_annotation_widget.dart';
import 'pd_acro_form.dart';
import 'pd_field.dart';
import 'pd_field_factory.dart';

/// A non-terminal field in an interactive form.
class PDNonTerminalField extends PDField {
  PDNonTerminalField(
      PDAcroForm acroForm, COSDictionary dictionary, PDNonTerminalField? parent)
      : super(acroForm, dictionary, parent);

  /// Returns the children of this field.
  List<PDField> getChildren() {
    final kids = cosObject.getCOSArray(COSName.kids);
    if (kids == null) {
      return [];
    }

    final children = <PDField>[];
    for (var i = 0; i < kids.length; i++) {
      var kid = kids.getObject(i);
      if (kid is COSObject) {
         kid = kid.object;
      }
      if (kid is COSDictionary) {
        // Avoid infinite recursion if child is same as parent
        if (kid == cosObject) {
          continue;
        }
        final field = PDFieldFactory.createField(acroForm, kid, this);
        if (field != null) {
          children.add(field);
        }
      }
    }
    return children;
  }

  /// Sets the children of this field.
  void setChildren(List<PDField> children) {
    final kids = COSArray();
    for (final child in children) {
      kids.add(child.cosObject);
    }
    cosObject.setItem(COSName.kids, kids);
  }

  @override
  List<PDAnnotationWidget> getWidgets() {
    return [];
  }
}


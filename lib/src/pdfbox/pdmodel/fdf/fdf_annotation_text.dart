import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../interactive/annotation/pd_annotation_text.dart';
import 'fdf_annotation.dart';

/// This represents a Text FDF annotation.
class FDFAnnotationText extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Text';

  /// Default constructor.
  FDFAnnotationText() : super() {
    annot.setItem(COSName.subtype, COSName.text);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationText.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationText.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.text);
    String? icon = element.getAttribute('icon');
    if (icon != null) {
      setIcon(icon);
    }
    String? state = element.getAttribute('state');
    if (state != null) {
      setState(state);
    }
    String? stateModel = element.getAttribute('statemodel');
    if (stateModel != null) {
      setStateModel(stateModel);
    }
  }

  /// This will set the icon (and hence appearance, AP taking precedence) For this annotation. See the
  /// PDAnnotationText.NAME_XXX constants for valid values.
  ///
  /// [icon] The name of the annotation
  void setIcon(String icon) {
    annot.setName(COSName.nameKey, icon);
  }

  /// This will retrieve the icon (and hence appearance, AP taking precedence) For this annotation. The default is
  /// NOTE.
  ///
  /// Returns The name of this annotation, see the PDAnnotationText.NAME_XXX constants.
  String getIcon() {
    return annot.getNameAsString(COSName.nameKey, PDAnnotationText.NAME_NOTE) ?? PDAnnotationText.NAME_NOTE;
  }

  /// This will retrieve the annotation state.
  ///
  /// Returns the annotation state
  String? getState() {
    return annot.getString(COSName.state);
  }

  /// This will set the annotation state.
  ///
  /// [state] the annotation state
  void setState(String state) {
    annot.setString(COSName.state, state);
  }

  /// This will retrieve the annotation state model.
  ///
  /// Returns the annotation state model
  String? getStateModel() {
    return annot.getString(COSName.stateModel);
  }

  /// This will set the annotation state model. Allowed values are "Marked" and "Review"
  ///
  /// [stateModel] the annotation state model
  void setStateModel(String stateModel) {
    annot.setString(COSName.stateModel, stateModel);
  }
}



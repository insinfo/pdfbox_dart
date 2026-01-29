import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_rectangle.dart';
import '../../pd_document.dart';
import 'pd_annotation_line.dart';
import 'pd_annotation_markup.dart';
import 'pd_border_effect_dictionary.dart';

/// This is the class that represents a FreeText annotation.
class PDAnnotationFreeText extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'FreeText';

  /// A plain free-text annotation, also known as a text box comment.
  static const String itFreeText = 'FreeText';

  /// A callout, associated with an area on the page through the callout line specified.
  static const String itFreeTextCallout = 'FreeTextCallout';

  /// The annotation is intended to function as a click-to-type or typewriter object.
  static const String itFreeTextTypeWriter = 'FreeTextTypeWriter';

  /// Constructor.
  PDAnnotationFreeText([COSDictionary? field])
      : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// Get the default appearance.
  String? getDefaultAppearance() {
    return dictionary.getString(COSName.defaultAppearance);
  }

  /// Set the default appearance.
  void setDefaultAppearance(String daValue) {
    dictionary.setString(COSName.defaultAppearance, daValue);
  }

  /// Get the default style string.
  String? getDefaultStyleString() {
    return dictionary.getString(COSName.ds);
  }

  /// Set the default style string.
  void setDefaultStyleString(String defaultStyleString) {
    dictionary.setString(COSName.ds, defaultStyleString);
  }

  /// This will get the 'quadding' or justification of the text to be displayed.
  /// 0 - Left (default)
  /// 1 - Centered
  /// 2 - Right
  int getQ() {
    return dictionary.getInt(COSName.q, 0) ?? 0;
  }

  /// This will set the quadding/justification of the text.
  void setQ(int q) {
    dictionary.setInt(COSName.q, q);
  }

  /// This will set the difference between the annotations "outer" rectangle defined by
  /// /Rect and the border.
  void setRectDifferences(double differenceLeft,
      [double? differenceTop,
      double? differenceRight,
      double? differenceBottom]) {
    if (differenceTop == null &&
        differenceRight == null &&
        differenceBottom == null) {
      setRectDifferences(
          differenceLeft, differenceLeft, differenceLeft, differenceLeft);
      return;
    }
    final margins = COSArray();
    margins.add(COSFloat(differenceLeft));
    margins.add(COSFloat(differenceTop ?? 0));
    margins.add(COSFloat(differenceRight ?? 0));
    margins.add(COSFloat(differenceBottom ?? 0));
    dictionary.setItem(COSName.rd, margins);
  }

  /// This will get the margin between the annotations "outer" rectangle defined by
  /// /Rect and the border.
  List<double> getRectDifferencesEntry() {
    final margin = dictionary.getCOSArray(COSName.rd);
    return margin != null ? margin.toDoubleList() : <double>[];
  }

  /// This will set the rectangle difference rectangle.
  void setRectDifference(PDRectangle rd) {
    dictionary.setItem(COSName.rd, rd.toCOSArray());
  }

  /// This will get the rectangle difference rectangle.
  PDRectangle? getRectDifference() {
    final rectDifference = dictionary.getCOSArray(COSName.rd);
    return rectDifference != null
        ? PDRectangle.fromCOSArray(rectDifference)
        : null;
  }

  /// This will set the coordinates of the callout line.
  void setCallout(List<double> callout) {
    final array = COSArray();
    for (final f in callout) {
      array.add(COSFloat(f));
    }
    dictionary.setItem(COSName.cl, array);
  }

  /// This will get the coordinates of the callout line.
  List<double>? getCallout() {
    final callout = dictionary.getCOSArray(COSName.cl);
    return callout?.toDoubleList();
  }

  /// This will set the line ending style.
  void setLineEndingStyle(String style) {
    dictionary.setName(COSName.le, style);
  }

  /// This will retrieve the line ending style.
  String getLineEndingStyle() {
    return dictionary.getNameAsString(COSName.le, PDAnnotationLine.leNone) ??
        PDAnnotationLine.leNone;
  }

  /// This will set the border effect dictionary.
  void setBorderEffect(PDBorderEffectDictionary be) {
    dictionary.setItem(COSName.be, be);
  }

  /// This will retrieve the border effect dictionary.
  PDBorderEffectDictionary? getBorderEffect() {
    final effectDict = dictionary.getCOSDictionary(COSName.be);
    return effectDict != null ? PDBorderEffectDictionary(effectDict) : null;
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDFreeTextAppearanceHandler logic when handlers are ported
  }
}

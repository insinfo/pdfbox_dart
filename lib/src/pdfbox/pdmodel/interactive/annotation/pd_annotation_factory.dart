import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import 'pd_annotation.dart';
import 'pd_annotation_link.dart';
import 'pd_annotation_text.dart';
import 'pd_annotation_unknown.dart';
import 'pd_annotation_widget.dart';
import 'pd_annotation_square.dart';
import 'pd_annotation_circle.dart';
import 'pd_annotation_popup.dart';
import 'pd_annotation_line.dart';
import 'pd_annotation_polyline.dart';
import 'pd_annotation_polygon.dart';
import 'pd_annotation_highlight.dart';
import 'pd_annotation_underline.dart';
import 'pd_annotation_strikeout.dart';
import 'pd_annotation_squiggly.dart';
import 'pd_annotation_file_attachment.dart';
import 'pd_annotation_free_text.dart';
import 'pd_annotation_ink.dart';
import 'pd_annotation_rubber_stamp.dart';
import 'pd_annotation_sound.dart';
import 'pd_annotation_caret.dart';

/// Factory that maps annotation dictionaries to typed wrappers.
class PDAnnotationFactory {
  const PDAnnotationFactory._();

  static const PDAnnotationFactory instance = PDAnnotationFactory._();

  PDAnnotation? createAnnotation(COSBase? base) {
    if (base == null) {
      return null;
    }
    final dictionaryBase = base is COSObject ? base.object : base;
    if (dictionaryBase is! COSDictionary) {
      return null;
    }
    final cached = PDAnnotation.getCached(dictionaryBase);
    if (cached != null) {
      return cached;
    }
    final subtype = dictionaryBase.getNameAsString(COSName.subtype);
    switch (subtype) {
      case 'Link':
        return PDAnnotationLink.fromDictionary(dictionaryBase);
      case 'Text':
        return PDAnnotationText.fromDictionary(dictionaryBase);
      case 'Widget':
        return PDAnnotationWidget.fromDictionary(dictionaryBase);
      case 'Line':
        return PDAnnotationLine(dictionaryBase);
      case 'PolyLine':
        return PDAnnotationPolyline(dictionaryBase);
      case 'Polygon':
        return PDAnnotationPolygon(dictionaryBase);
      case 'Highlight':
        return PDAnnotationHighlight(dictionaryBase);
      case 'Underline':
        return PDAnnotationUnderline(dictionaryBase);
      case 'StrikeOut':
        return PDAnnotationStrikeout(dictionaryBase);
      case 'Squiggly':
        return PDAnnotationSquiggly(dictionaryBase);
      case 'FileAttachment':
        return PDAnnotationFileAttachment(dictionaryBase);
      case 'FreeText':
        return PDAnnotationFreeText(dictionaryBase);
      case 'Ink':
        return PDAnnotationInk(dictionaryBase);
      case 'Stamp':
        return PDAnnotationRubberStamp(dictionaryBase);
      case 'Sound':
        return PDAnnotationSound(dictionaryBase);
      case 'Caret':
        return PDAnnotationCaret(dictionaryBase);
      case 'Square':
        return PDAnnotationSquare(dictionaryBase);
      case 'Circle':
        return PDAnnotationCircle(dictionaryBase);
      case 'Popup':
        return PDAnnotationPopup(dictionaryBase);
      default:
        return PDAnnotationUnknown.fromDictionary(dictionaryBase);
    }
  }
}


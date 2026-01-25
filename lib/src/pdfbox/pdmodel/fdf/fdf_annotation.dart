import 'package:logging/logging.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_string.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_stream.dart';
import '../common/pd_rectangle.dart';
import '../interactive/annotation/pd_border_style_dictionary.dart';
import '../interactive/annotation/pd_border_effect_dictionary.dart';

import 'fdf_annotation_caret.dart';
import 'fdf_annotation_circle.dart';
import 'fdf_annotation_file_attachment.dart';
import 'fdf_annotation_free_text.dart';
import 'fdf_annotation_highlight.dart';
import 'fdf_annotation_ink.dart';
import 'fdf_annotation_line.dart';
import 'fdf_annotation_link.dart';
import 'fdf_annotation_polygon.dart';
import 'fdf_annotation_polyline.dart';
import 'fdf_annotation_sound.dart';
import 'fdf_annotation_square.dart';
import 'fdf_annotation_squiggly.dart';
import 'fdf_annotation_stamp.dart';
import 'fdf_annotation_strike_out.dart';
import 'fdf_annotation_text.dart';
import 'fdf_annotation_underline.dart';

/// This represents an FDF annotation that is part of the FDF document.
abstract class FDFAnnotation implements COSObjectable {
  static final Logger _log = Logger('FDFAnnotation');

  /// An annotation flag.
  static const int FLAG_INVISIBLE = 1;
  /// An annotation flag.
  static const int FLAG_HIDDEN = 1 << 1;
  /// An annotation flag.
  static const int FLAG_PRINTED = 1 << 2;
  /// An annotation flag.
  static const int FLAG_NO_ZOOM = 1 << 3;
  /// An annotation flag.
  static const int FLAG_NO_ROTATE = 1 << 4;
  /// An annotation flag.
  static const int FLAG_NO_VIEW = 1 << 5;
  /// An annotation flag.
  static const int FLAG_READ_ONLY = 1 << 6;
  /// An annotation flag.
  static const int FLAG_LOCKED = 1 << 7;
  /// An annotation flag.
  static const int FLAG_TOGGLE_NO_VIEW = 1 << 8;
  /// An annotation flag.
  static const int FLAG_LOCKED_CONTENTS = 1 << 9;

  /// Annotation dictionary.
  final COSDictionary annot;

  /// Default constructor.
  FDFAnnotation() : annot = COSDictionary() {
    annot.setItem(COSName.type, COSName.annot);
  }

  /// Constructor.
  ///
  /// [a] The FDF annotation.
  FDFAnnotation.fromDictionary(this.annot);

  // XML Element constructor skipped for now - XML dependency not ready.

  /// Create the correct FDFAnnotation.
  ///
  /// [fdfDic] The FDF dictionary.
  ///
  /// Returns A newly created FDFAnnotation
  static FDFAnnotation? create(COSDictionary? fdfDic) {
    if (fdfDic == null) {
      return null;
    }
    String? fdfDicName = fdfDic.getNameAsString(COSName.subtype);
    if (FDFAnnotationText.SUBTYPE == fdfDicName) {
      return FDFAnnotationText.fromDictionary(fdfDic);
    } else if (FDFAnnotationCaret.SUBTYPE == fdfDicName) {
      return FDFAnnotationCaret.fromDictionary(fdfDic);
    } else if (FDFAnnotationFreeText.SUBTYPE == fdfDicName) {
      return FDFAnnotationFreeText.fromDictionary(fdfDic);
    } else if (FDFAnnotationFileAttachment.SUBTYPE == fdfDicName) {
      return FDFAnnotationFileAttachment.fromDictionary(fdfDic);
    } else if (FDFAnnotationHighlight.SUBTYPE == fdfDicName) {
      return FDFAnnotationHighlight.fromDictionary(fdfDic);
    } else if (FDFAnnotationInk.SUBTYPE == fdfDicName) {
      return FDFAnnotationInk.fromDictionary(fdfDic);
    } else if (FDFAnnotationLine.SUBTYPE == fdfDicName) {
      return FDFAnnotationLine.fromDictionary(fdfDic);
    } else if (FDFAnnotationLink.SUBTYPE == fdfDicName) {
      return FDFAnnotationLink.fromDictionary(fdfDic);
    } else if (FDFAnnotationCircle.SUBTYPE == fdfDicName) {
      return FDFAnnotationCircle.fromDictionary(fdfDic);
    } else if (FDFAnnotationSquare.SUBTYPE == fdfDicName) {
      return FDFAnnotationSquare.fromDictionary(fdfDic);
    } else if (FDFAnnotationPolygon.SUBTYPE == fdfDicName) {
      return FDFAnnotationPolygon.fromDictionary(fdfDic);
    } else if (FDFAnnotationPolyline.SUBTYPE == fdfDicName) {
      return FDFAnnotationPolyline.fromDictionary(fdfDic);
    } else if (FDFAnnotationSound.SUBTYPE == fdfDicName) {
      return FDFAnnotationSound.fromDictionary(fdfDic);
    } else if (FDFAnnotationSquiggly.SUBTYPE == fdfDicName) {
      return FDFAnnotationSquiggly.fromDictionary(fdfDic);
    } else if (FDFAnnotationStamp.SUBTYPE == fdfDicName) {
      return FDFAnnotationStamp.fromDictionary(fdfDic);
    } else if (FDFAnnotationStrikeOut.SUBTYPE == fdfDicName) {
      return FDFAnnotationStrikeOut.fromDictionary(fdfDic);
    } else if (FDFAnnotationUnderline.SUBTYPE == fdfDicName) {
      return FDFAnnotationUnderline.fromDictionary(fdfDic);
    } else {
      _log.warning("Unknown or unsupported annotation type '$fdfDicName'");
      return null;
    }
  }

  /// Convert this standard java object to a COS object.
  @override
  COSDictionary get cosObject => annot;

  /// This will get the page number or null if it does not exist.
  ///
  /// Returns The page number.
  int? getPage() {
    return annot.getInt(COSName.page);
  }

  /// This will set the page.
  ///
  /// [page] The page number.
  void setPage(int page) {
    annot.setInt(COSName.page, page);
  }

  /// Get the annotation color.
  ///
  /// Returns The annotation color, or null if there is none.
  List<double>? getColor() {
    return _getColor(COSName.c);
  }

  List<double>? _getColor(COSName colorName) {
    COSArray? array = annot.getCOSArray(colorName);
    if (array != null) {
      return array.toDoubleList();
    }
    return null;
  }

  /// Set the annotation color.
  ///
  /// [c] The annotation color.
  void setColor(List<double>? c) {
    if (c != null) {
      annot.setItem(COSName.c, COSArray(c.map((e) => COSFloat(e)).toList()));
    } else {
      annot.removeItem(COSName.c);
    }
  }

  /// Modification date.
  ///
  /// Returns The date as a string.
  String? getDate() {
    return annot.getString(COSName.m);
  }

  /// The annotation modification date.
  ///
  /// [date] The date to store in the FDF annotation.
  void setDate(String? date) {
    annot.setString(COSName.m, date);
  }

  /// Get the invisible flag.
  bool isInvisible() {
    return annot.getFlag(COSName.f, FLAG_INVISIBLE);
  }

  /// Set the invisible flag.
  void setInvisible(bool invisible) {
    annot.setFlag(COSName.f, FLAG_INVISIBLE, invisible);
  }

  /// Get the hidden flag.
  bool isHidden() {
    return annot.getFlag(COSName.f, FLAG_HIDDEN);
  }

  /// Set the hidden flag.
  void setHidden(bool hidden) {
    annot.setFlag(COSName.f, FLAG_HIDDEN, hidden);
  }

  /// Get the printed flag.
  bool isPrinted() {
    return annot.getFlag(COSName.f, FLAG_PRINTED);
  }

  /// Set the printed flag.
  void setPrinted(bool printed) {
    annot.setFlag(COSName.f, FLAG_PRINTED, printed);
  }

  /// Get the noZoom flag.
  bool isNoZoom() {
    return annot.getFlag(COSName.f, FLAG_NO_ZOOM);
  }

  /// Set the noZoom flag.
  void setNoZoom(bool noZoom) {
    annot.setFlag(COSName.f, FLAG_NO_ZOOM, noZoom);
  }

  /// Get the noRotate flag.
  bool isNoRotate() {
    return annot.getFlag(COSName.f, FLAG_NO_ROTATE);
  }

  /// Set the noRotate flag.
  void setNoRotate(bool noRotate) {
    annot.setFlag(COSName.f, FLAG_NO_ROTATE, noRotate);
  }

  /// Get the noView flag.
  bool isNoView() {
    return annot.getFlag(COSName.f, FLAG_NO_VIEW);
  }

  /// Set the noView flag.
  void setNoView(bool noView) {
    annot.setFlag(COSName.f, FLAG_NO_VIEW, noView);
  }

  /// Get the readOnly flag.
  bool isReadOnly() {
    return annot.getFlag(COSName.f, FLAG_READ_ONLY);
  }

  /// Set the readOnly flag.
  void setReadOnly(bool readOnly) {
    annot.setFlag(COSName.f, FLAG_READ_ONLY, readOnly);
  }

  /// Get the locked flag.
  bool isLocked() {
    return annot.getFlag(COSName.f, FLAG_LOCKED);
  }

  /// Set the locked flag.
  void setLocked(bool locked) {
    annot.setFlag(COSName.f, FLAG_LOCKED, locked);
  }

  /// Get the toggleNoView flag.
  bool isToggleNoView() {
    return annot.getFlag(COSName.f, FLAG_TOGGLE_NO_VIEW);
  }

  /// Set the toggleNoView flag.
  void setToggleNoView(bool toggleNoView) {
    annot.setFlag(COSName.f, FLAG_TOGGLE_NO_VIEW, toggleNoView);
  }

  /// Get the LockedContents flag.
  bool isLockedContents() {
    return annot.getFlag(COSName.f, FLAG_LOCKED_CONTENTS);
  }

  /// Set the LockedContents flag.
  void setLockedContents(bool lockedContents) {
    annot.setFlag(COSName.f, FLAG_LOCKED_CONTENTS, lockedContents);
  }

  /// Set a unique name for an annotation.
  ///
  /// [name] The unique annotation name.
  void setName(String name) {
    annot.setString(COSName.nm, name);
  }

  /// Get the annotation name.
  ///
  /// Returns The unique name of the annotation.
  String? getName() {
    return annot.getString(COSName.nm);
  }

  /// Set the rectangle associated with this annotation.
  ///
  /// [rectangle] The annotation rectangle.
  void setRectangle(PDRectangle rectangle) {
    annot.setItem(COSName.rect, rectangle.toCOSArray());
  }

  /// The rectangle associated with this annotation.
  ///
  /// Returns The annotation rectangle.
  PDRectangle? getRectangle() {
    COSArray? rectArray = annot.getCOSArray(COSName.rect);
    return rectArray != null ? PDRectangle.fromCOSArray(rectArray) : null;
  }

  /// Set the contents, or a description, for an annotation.
  ///
  /// [contents] The annotation contents, or a description.
  void setContents(String contents) {
    annot.setString(COSName.contents, contents);
  }

  /// Get the text, or a description, of the annotation.
  ///
  /// Returns The text, or a description, of the annotation.
  String? getContents() {
    return annot.getString(COSName.contents);
  }

  /// Set a unique title for an annotation.
  void setTitle(String title) {
    annot.setString(COSName.t, title);
  }

  /// Get the annotation title.
  String? getTitle() {
    return annot.getString(COSName.t);
  }

  /// The annotation create date.
  ///
  /// Returns The date of the creation of the annotation date
  DateTime? getCreationDate() {
    return annot.getDate(COSName.creationDate);
  }

  /// Set the creation date.
  ///
  /// [date] The date the annotation was created.
  void setCreationDate(DateTime date) {
    annot.setDate(COSName.creationDate, date);
  }

  /// Set the annotation opacity.
  ///
  /// [opacity] The new opacity value.
  void setOpacity(double opacity) {
    annot.setFloat(COSName.ca, opacity);
  }

  /// Get the opacity value.
  ///
  /// Returns The opacity of the annotation.
  double getOpacity() {
    return annot.getFloat(COSName.ca, 1.0) ?? 1.0;
  }

  /// A short description of the annotation.
  ///
  /// [subject] The annotation subject.
  void setSubject(String subject) {
    annot.setString(COSName.subj, subject);
  }

  /// Get the description of the annotation.
  ///
  /// Returns The subject of the annotation.
  String? getSubject() {
    return annot.getString(COSName.subj);
  }

  /// The intent of the annotation.
  ///
  /// [intent] The annotation's intent.
  void setIntent(String intent) {
    annot.setName(COSName.it, intent);
  }

  /// Get the intent of the annotation.
  ///
  /// Returns The intent of the annotation.
  String? getIntent() {
    return annot.getNameAsString(COSName.it);
  }

  /// This will retrieve the rich text stream which is displayed in the popup window.
  ///
  /// Returns the rich text stream.
  String? getRichContents() {
    return _getStringOrStream(annot.getDictionaryObject(COSName.rc));
  }

  /// This will set the rich text stream which is displayed in the popup window.
  ///
  /// [rc] the rich text stream.
  void setRichContents(String rc) {
    annot.setItem(COSName.rc, COSString(rc));
  }

  /// This will set the border style dictionary, specifying the width and dash pattern used in drawing the annotation.
  ///
  /// [bs] the border style dictionary to set.
  void setBorderStyle(PDBorderStyleDictionary bs) {
    annot.setItem(COSName.bs, bs);
  }

  /// This will retrieve the border style dictionary, specifying the width and dash pattern used in drawing the
  /// annotation.
  ///
  /// Returns the border style dictionary.
  PDBorderStyleDictionary? getBorderStyle() {
    COSDictionary? bs = annot.getCOSDictionary(COSName.bs);
    return bs != null ? PDBorderStyleDictionary(bs) : null;
  }

  /// This will set the border effect dictionary, describing the effect applied to the border described by the BS
  /// entry.
  ///
  /// [be] the border effect dictionary to set.
  void setBorderEffect(PDBorderEffectDictionary be) {
    annot.setItem(COSName.be, be);
  }

  /// This will retrieve the border style dictionary, describing the effect applied to the border described by the BS
  /// entry.
  ///
  /// Returns the border effect dictionary.
  PDBorderEffectDictionary? getBorderEffect() {
    COSDictionary? be = annot.getCOSDictionary(COSName.be);
    return be != null ? PDBorderEffectDictionary(be) : null;
  }

  /// Get a text or text stream.
  ///
  /// Some dictionary entries allow either a text or a text stream.
  ///
  /// [base] the potential text or text stream
  /// Returns the text stream
  String _getStringOrStream(COSBase? base) {
    if (base == null) {
      return "";
    } else if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      // TODO: Implement proper text decoding if needed, for now using ASCII/Latin1 assumption or empty
      if (base.data != null) {
          return String.fromCharCodes(base.data!);
      }
      return "";
    } else {
      return "";
    }
  }

  // richContentsToString omitted as it uses XML Node/Element.
}

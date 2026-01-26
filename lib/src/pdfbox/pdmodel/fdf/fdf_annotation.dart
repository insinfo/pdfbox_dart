import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/io/export.dart';
import 'package:pdfbox_dart/src/pdfbox/util/pdf_date.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';
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

  /// Constructor from XML Element.
  FDFAnnotation.fromXml(XmlElement element) : annot = COSDictionary() {
    annot.setItem(COSName.type, COSName.annot);

    String? page = element.getAttribute('page');
    if (page == null || page.isEmpty) {
      throw IOException("Error: missing required attribute 'page'");
    }
    setPage(int.parse(page));

    String? color = element.getAttribute('color');
    if (color != null && color.length == 7 && color.startsWith('#')) {
      int colorValue = int.parse(color.substring(1), radix: 16);
      setColor(_colorFromInt(colorValue));
    }

    setDate(element.getAttribute('date'));

    String? flags = element.getAttribute('flags');
    if (flags != null) {
      List<String> flagTokens = flags.split(',');
      for (String flagToken in flagTokens) {
        switch (flagToken) {
          case 'invisible':
            setInvisible(true);
            break;
          case 'hidden':
            setHidden(true);
            break;
          case 'print':
            setPrinted(true);
            break;
          case 'nozoom':
            setNoZoom(true);
            break;
          case 'norotate':
            setNoRotate(true);
            break;
          case 'noview':
            setNoView(true);
            break;
          case 'readonly':
            setReadOnly(true);
            break;
          case 'locked':
            setLocked(true);
            break;
          case 'togglenoview':
            setToggleNoView(true);
            break;
        }
      }
    }

    setName(element.getAttribute('name') ?? '');

    String? rect = element.getAttribute('rect');
    if (rect == null) {
      throw IOException("Error: missing attribute 'rect'");
    }
    List<double> values = _parseRectangleAttributes(rect, "Error: wrong amount of numbers in attribute 'rect'");
    setRectangle(PDRectangle(values[0], values[1], values[2] - values[0], values[3] - values[1]));
    
    setTitle(element.getAttribute('title') ?? '');

    setCreationDate(PdfDate.parse(element.getAttribute('creationdate')) ?? DateTime.now());
    
    String? opac = element.getAttribute('opacity');
    if (opac != null && opac.isNotEmpty) {
      setOpacity(double.parse(opac));
    }
    
    setSubject(element.getAttribute('subject') ?? '');

    String? intent = element.getAttribute('intent');
    if (intent == null || intent.isEmpty) {
      intent = element.getAttribute('IT');
    }
    if (intent != null && intent.isNotEmpty) {
      setIntent(intent);
    }

    // Contents
    var contents = element.findElements('contents').firstOrNull;
    if (contents != null) {
      setContents(contents.innerText);
    }

    // Rich Contents
    var richContents = element.findElements('contents-richtext').firstOrNull;
    if (richContents != null) {
      setRichContents(_richContentsToString(richContents, true));
      setContents(richContents.innerText.trim());
    }

    PDBorderStyleDictionary borderStyle = PDBorderStyleDictionary(COSDictionary());
    String? width = element.getAttribute('width');
    if (width != null && width.isNotEmpty) {
      borderStyle.width = double.parse(width);
    }
    
    if (borderStyle.width > 0) {
      String? style = element.getAttribute('style');
      if (style != null && style.isNotEmpty) {
        switch (style) {
          case 'dash':
            borderStyle.style = PDBorderStyleDictionary.styleDashed;
            break;
          case 'bevelled':
            borderStyle.style = PDBorderStyleDictionary.styleBeveled;
            break;
          case 'inset':
            borderStyle.style = PDBorderStyleDictionary.styleInset;
            break;
          case 'underline':
            borderStyle.style = PDBorderStyleDictionary.styleUnderline;
            break;
          case 'cloudy':
            borderStyle.style = PDBorderStyleDictionary.styleSolid;
            PDBorderEffectDictionary borderEffect = PDBorderEffectDictionary(COSDictionary());
            borderEffect.setStyle(PDBorderEffectDictionary.STYLE_CLOUDY);
            String? intensity = element.getAttribute('intensity');
            if (intensity != null && intensity.isNotEmpty) {
              borderEffect.setIntensity(double.parse(intensity));
            }
            setBorderEffect(borderEffect);
            break;
          default:
            borderStyle.style = PDBorderStyleDictionary.styleSolid;
            break;
        }
      }
      
      String? dashes = element.getAttribute('dashes');
      if (dashes != null && dashes.isNotEmpty) {
        List<String> dashesValues = dashes.split(',');
        List<double> dashPattern = [];
        for (String dashesValue in dashesValues) {
          dashPattern.add(double.parse(dashesValue));
        }
        borderStyle.dashPattern = dashPattern;
      }
      setBorderStyle(borderStyle);
    }
  }

  List<double> _parseRectangleAttributes(String rect, String errorMessage) {
    List<String> rectValues = rect.split(',');
    if (rectValues.length != 4) {
      throw IOException(errorMessage);
    }
    return rectValues.map((e) => double.parse(e)).toList();
  }

  List<double> _colorFromInt(int colorValue) {
    int r = (colorValue >> 16) & 0xFF;
    int g = (colorValue >> 8) & 0xFF;
    int b = (colorValue >> 0) & 0xFF;
    return [r / 255.0, g / 255.0, b / 255.0];
  }
  
  String _richContentsToString(XmlNode node, bool root) {
    return node.toXmlString();
  }


  /// Create the correct FDFAnnotation.
  ///
  /// [fdfDic] The FDF dictionary.
  ///
  /// Returns A newly created FDFAnnotation
  static FDFAnnotation? create(COSDictionary? fdfDic) {
    if (fdfDic == null) {
      return null;
    }
    COSName? type = fdfDic.getCOSName(COSName.subtype);
    if (COSName.text == type) {
      return FDFAnnotationText.fromDictionary(fdfDic);
    } else if (COSName.caret == type) {
      return FDFAnnotationCaret.fromDictionary(fdfDic);
    } else if (COSName.freeText == type) {
      return FDFAnnotationFreeText.fromDictionary(fdfDic);
    } else if (COSName.fileAttachment == type) {
      return FDFAnnotationFileAttachment.fromDictionary(fdfDic);
    } else if (COSName.highlight == type) {
      return FDFAnnotationHighlight.fromDictionary(fdfDic);
    } else if (COSName.ink == type) {
      return FDFAnnotationInk.fromDictionary(fdfDic);
    } else if (COSName.line == type) {
      return FDFAnnotationLine.fromDictionary(fdfDic);
    } else if (COSName.link == type) {
      return FDFAnnotationLink.fromDictionary(fdfDic);
    } else if (COSName.circle == type) {
      return FDFAnnotationCircle.fromDictionary(fdfDic);
    } else if (COSName.square == type) {
      return FDFAnnotationSquare.fromDictionary(fdfDic);
    } else if (COSName.polygon == type) {
      return FDFAnnotationPolygon.fromDictionary(fdfDic);
    } else if (COSName.polyline == type) {
      return FDFAnnotationPolyline.fromDictionary(fdfDic);
    } else if (COSName.sound == type) {
      return FDFAnnotationSound.fromDictionary(fdfDic);
    } else if (COSName.squiggly == type) {
      return FDFAnnotationSquiggly.fromDictionary(fdfDic);
    } else if (COSName.stamp == type) {
      return FDFAnnotationStamp.fromDictionary(fdfDic);
    } else if (COSName.strikeOut == type) {
      return FDFAnnotationStrikeOut.fromDictionary(fdfDic);
    } else if (COSName.underline == type) {
      return FDFAnnotationUnderline.fromDictionary(fdfDic);
    } else {
      _log.warning("Unknown or unsupported annotation type '${type?.name}'");
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
      return _decodeStreamText(base) ?? "";
    } else {
      return "";
    }
  }

  String? _decodeStreamText(COSStream stream) {
    try {
      final bytes = stream.decode() ?? stream.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return latin1.decode(bytes);
      }
    } catch (_) {
      return null;
    }
  }

  // richContentsToString omitted as it uses XML Node/Element.
}


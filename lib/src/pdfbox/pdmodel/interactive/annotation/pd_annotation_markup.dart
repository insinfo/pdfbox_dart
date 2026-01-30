import 'dart:convert';
import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../../cos/cos_string.dart';
import 'pd_annotation.dart';
import 'pd_annotation_popup.dart';
import 'pd_external_data_dictionary.dart';

import 'pd_border_style_dictionary.dart';

/// This class represents the additional fields of a Markup type Annotation.
/// See section 12.5.6 of ISO32000-1:2008 (starting with page 390) for details on annotation types.
class PDAnnotationMarkup extends PDAnnotation {
  /// Constant for an annotation reply type.
  static const String rtReply = 'R';

  /// Constant for an annotation reply type.
  static const String rtGroup = 'Group';

  /// Constructor.
  PDAnnotationMarkup([COSDictionary? dict])
      : super.internal(dict ?? COSDictionary());

  /// Retrieve the string used as the title of the popup window shown when open and active
  /// (by convention this identifies who added the annotation).
  String? get titlePopup => dictionary.getString(COSName.t);

  /// Set the string used as the title of the popup window.
  set titlePopup(String? t) {
    if (t == null) {
      dictionary.removeItem(COSName.t);
    } else {
      dictionary.setString(COSName.t, t);
    }
  }

  /// This will retrieve the popup annotation used for entering/editing the text for this annotation.
  PDAnnotationPopup? get popup {
    final dict = dictionary.getCOSDictionary(COSName.popup);
    return dict != null ? PDAnnotationPopup(dict) : null;
  }

  /// This will set the popup annotation used for entering/editing the text for this annotation.
  set popup(PDAnnotationPopup? popup) {
    if (popup == null) {
      dictionary.removeItem(COSName.popup);
    } else {
      dictionary.setItem(COSName.popup, popup);
    }
  }

  /// This will retrieve the constant opacity value used when rendering the annotation (excluding any popup).
  double get constantOpacity =>
      dictionary.getFloat(COSName.ca, 1.0) ?? 1.0;

  /// This will set the constant opacity value used when rendering the annotation (excluding any popup).
  set constantOpacity(double ca) => dictionary.setFloat(COSName.ca, ca);

  /// This will retrieve the rich text stream which is displayed in the popup window.
  String? get richContents {
    final base = dictionary.getDictionaryObject(COSName.rc);
    if (base is COSString) {
      return base.string;
    } else if (base is COSStream) {
      final bytes = base.decode();
      return bytes != null ? utf8.decode(bytes, allowMalformed: true) : null;
    }
    return null;
  }

  /// This will set the rich text stream which is displayed in the popup window.
  set richContents(String? rc) {
    if (rc == null) {
      dictionary.removeItem(COSName.rc);
    } else {
      dictionary.setItem(COSName.rc, COSString(rc));
    }
  }

  /// This will retrieve the date and time the annotation was created.
  DateTime? get creationDate => dictionary.getDate(COSName.creationDate);

  /// This will set the date and time the annotation was created.
  set creationDate(DateTime? creationDate) {
    if (creationDate == null) {
      dictionary.removeItem(COSName.creationDate);
    } else {
      dictionary.setDate(COSName.creationDate, creationDate);
    }
  }

  /// This will retrieve the annotation to which this one is "In Reply To" the actual relationship
  /// is specified by the RT entry.
  PDAnnotation? get inReplyTo {
    final base = dictionary.getCOSDictionary(COSName.irt);
    if (base == null) return null;
    return PDAnnotation.createAnnotation(base);
  }

  /// This will set the annotation to which this one is "In Reply To".
  set inReplyTo(PDAnnotation? irt) {
    if (irt == null) {
      dictionary.removeItem(COSName.irt);
    } else {
      dictionary.setItem(COSName.irt, irt);
    }
  }

  /// This will retrieve the short description of the subject of the annotation.
  String? get subject => dictionary.getString(COSName.subj);

  /// This will set the short description of the subject of the annotation.
  set subject(String? subj) {
    if (subj == null) {
      dictionary.removeItem(COSName.subj);
    } else {
      dictionary.setString(COSName.subj, subj);
    }
  }

  /// This will retrieve the Reply Type (relationship) with the annotation in the IRT entry.
  /// See the RT_* constants for the available values.
  String get replyType =>
      dictionary.getNameAsString(COSName.rt, rtReply) ?? rtReply;

  /// This will set the Reply Type (relationship).
  set replyType(String? rt) {
    if (rt == null) {
      dictionary.removeItem(COSName.rt);
    } else {
      dictionary.setName(COSName.rt, rt);
    }
  }

  /// This will retrieve the intent of the annotation.
  String? get intent => dictionary.getNameAsString(COSName.it);

  /// This will set the intent of the annotation.
  set intent(String? it) {
    if (it == null) {
      dictionary.removeItem(COSName.it);
    } else {
      dictionary.setName(COSName.it, it);
    }
  }

  /// This will return the external data dictionary.
  PDExternalDataDictionary? get externalData {
    final exData = dictionary.getCOSDictionary(COSName.exData);
    return exData != null ? PDExternalDataDictionary(exData) : null;
  }

  /// This will set the external data dictionary.
  set externalData(PDExternalDataDictionary? externalData) {
    if (externalData == null) {
      dictionary.removeItem(COSName.exData);
    } else {
      dictionary.setItem(COSName.exData, externalData);
    }
  }

  /// This will retrieve the border style dictionary, specifying the width and dash pattern used in drawing the line.
  PDBorderStyleDictionary? get borderStyle {
    final bs = dictionary.getCOSDictionary(COSName.bs);
    return bs != null ? PDBorderStyleDictionary(bs) : null;
  }

  /// This will set the border style dictionary, specifying the width and dash pattern used in drawing the line.
  set borderStyle(PDBorderStyleDictionary? bs) {
    if (bs == null) {
      dictionary.removeItem(COSName.bs);
    } else {
      dictionary.setItem(COSName.bs, bs);
    }
  }

  /// This will retrieve the border array, specifying the width and dash pattern used in drawing the line.
  @override
  COSArray get border => dictionary.getCOSArray(COSName.border) ?? COSArray();

  /// This will set the border array, specifying the width and dash pattern used in drawing the line.
  set border(COSArray? border) {
    if (border == null) {
      dictionary.removeItem(COSName.border);
    } else {
      dictionary.setItem(COSName.border, border);
    }
  }
}

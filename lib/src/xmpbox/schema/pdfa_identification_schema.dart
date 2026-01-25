import '../xmp_metadata.dart';
import '../type/abstract_field.dart';
import '../type/attribute.dart';
import '../type/bad_field_value_exception.dart';
import '../type/integer_type.dart';
import '../type/text_type.dart';
import 'xmp_schema.dart';

/// Representation of PDF/A Identification Schema.
/// Ported from org.apache.xmpbox.schema.PDFAIdentificationSchema
/// 
/// Namespace: http://www.aiim.org/pdfa/ns/id/
/// Preferred prefix: pdfaid
class PDFAIdentificationSchema extends XMPSchema {
  static const String defaultPrefix = "pdfaid";
  static const String defaultNamespace = "http://www.aiim.org/pdfa/ns/id/";

  static const String part = "part";
  static const String amd = "amd";
  static const String conformance = "conformance";
  static const String rev = "rev"; // PDFBOX-6088

  /// Constructor of a PDF/A Identification schema.
  PDFAIdentificationSchema(XMPMetadata metadata) 
      : super.withNsAndPrefix(metadata, defaultNamespace, defaultPrefix);

  /// Constructor with specified prefix.
  PDFAIdentificationSchema.withPrefix(XMPMetadata metadata, String prefix)
      : super.withNsAndPrefix(metadata, defaultNamespace, prefix);

  /// Set the PDF/A Version identifier (with string).
  void setPartValueWithString(String value) {
    IntegerType partProp = IntegerType(metadata, namespace, prefix, part, value);
    addProperty(partProp);
  }

  /// Set the PDF/A Version identifier (with an int).
  void setPartValueWithInt(int value) {
    IntegerType partProp = IntegerType(metadata, namespace, prefix, part, value);
    addProperty(partProp);
  }

  /// Set the PDF/A Version identifier (with an int).
  void setPart(int value) {
    setPartValueWithInt(value);
  }

  /// Set the PDF/A Version identifier.
  void setPartProperty(IntegerType partProp) {
    addProperty(partProp);
  }

  /// Set the PDF/A amendment identifier.
  void setAmd(String value) {
    TextType amdProp = createTextType(amd, value);
    addProperty(amdProp);
  }

  /// Set the PDF/A amendment identifier.
  void setAmdProperty(TextType amdProp) {
    addProperty(amdProp);
  }

  /// Set the PDF/A conformance level.
  /// Throws BadFieldValueException if conformance value not 'A', 'B', 'U' (PDF/A-2 and PDF/A-3),
  /// 'e', 'f' (PDF/A-4).
  void setConformance(String value) {
    TextType conf = createTextType(conformance, value);
    setConformanceProperty(conf);
  }

  /// Set the PDF/A conformance level.
  /// Throws BadFieldValueException if conformance value not 'A', 'B', 'U' (PDF/A-2 and PDF/A-3),
  /// 'e', 'f' (PDF/A-4).
  void setConformanceProperty(TextType conf) {
    String? value = conf.stringValue;
    if (value == "A" || value == "B" || value == "U" ||
        value == "e" || value == "f") {
      addProperty(conf);
    } else {
      throw BadFieldValueException(
          "The value '$value' isn't a valid PDF/A conformance level (must be A, B, U, e or f)");
    }
  }

  /// Give the PDFAVersionId (as an integer).
  int? getPart() {
    IntegerType? tmp = getPartProperty();
    return tmp?.value;
  }

  /// Give the property corresponding to the PDF/A Version id.
  IntegerType? getPartProperty() {
    AbstractField? tmp = getProperty(part);
    if (tmp is IntegerType) {
      return tmp;
    }
    return null;
  }

  /// Give the PDFAAmendmentId (as a String).
  String? getAmendment() {
    AbstractField? tmp = getProperty(amd);
    if (tmp is TextType) {
      return tmp.stringValue;
    }
    return null;
  }

  /// Give the property corresponding to the PDF/A Amendment id.
  TextType? getAmdProperty() {
    AbstractField? tmp = getProperty(amd);
    if (tmp is TextType) {
      return tmp;
    }
    return null;
  }

  /// Give the PDF/A Amendment Id (as a String).
  String? getAmd() {
    TextType? tmp = getAmdProperty();
    if (tmp == null) {
      for (Attribute attribute in getAllAttributes()) {
        if (attribute.name == amd) {
          return attribute.value;
        }
      }
      return null;
    } else {
      return tmp.stringValue;
    }
  }

  /// Give the property corresponding to the PDF/A Conformance id.
  TextType? getConformanceProperty() {
    AbstractField? tmp = getProperty(conformance);
    if (tmp is TextType) {
      return tmp;
    }
    return null;
  }

  /// Give the Conformance id.
  String? getConformance() {
    TextType? tt = getConformanceProperty();
    if (tt == null) {
      for (Attribute attribute in getAllAttributes()) {
        if (attribute.name == conformance) {
          return attribute.value;
        }
      }
      return null;
    } else {
      return tt.stringValue;
    }
  }

  /// Set the PDF/A revision (with string).
  void setRevValueWithString(String value) {
    IntegerType revProp = IntegerType(metadata, namespace, prefix, rev, value);
    addProperty(revProp);
  }

  /// Set the PDF/A revision (with an int).
  void setRevValueWithInt(int value) {
    IntegerType revProp = IntegerType(metadata, namespace, prefix, rev, value);
    addProperty(revProp);
  }

  /// Set the PDF/A revision identifier (with an int).
  void setRev(int value) {
    setRevValueWithInt(value);
  }

  /// Set the PDF/A revision identifier.
  void setRevProperty(IntegerType revProp) {
    addProperty(revProp);
  }

  /// Give the property corresponding to the PDF/A revision.
  IntegerType? getRevProperty() {
    AbstractField? tmp = getProperty(rev);
    if (tmp is IntegerType) {
      return tmp;
    }
    return null;
  }

  /// Give the PDF/A revision (as an integer).
  int? getRev() {
    IntegerType? tmp = getRevProperty();
    return tmp?.value;
  }
}


import '../xmp_metadata.dart';
import '../type/text_type.dart';
import '../type/abstract_field.dart';
import 'xmp_schema.dart';

/// Representation of Adobe PDF Schema.
/// Ported from org.apache.xmpbox.schema.AdobePDFSchema
/// 
/// Namespace: http://ns.adobe.com/pdf/1.3/
/// Preferred prefix: pdf
class AdobePDFSchema extends XMPSchema {
  static const String defaultPrefix = "pdf";
  static const String defaultNamespace = "http://ns.adobe.com/pdf/1.3/";

  static const String keywords = "Keywords";
  static const String pdfVersion = "PDFVersion";
  static const String producer = "Producer";

  /// Constructor of an Adobe PDF schema with preferred prefix.
  AdobePDFSchema(XMPMetadata metadata) 
      : super.withNsAndPrefix(metadata, defaultNamespace, defaultPrefix);

  /// Constructor of an Adobe PDF schema with specified prefix.
  AdobePDFSchema.withPrefix(XMPMetadata metadata, String ownPrefix)
      : super.withNsAndPrefix(metadata, defaultNamespace, ownPrefix);

  /// Set the PDF keywords.
  void setKeywords(String value) {
    TextType kw = createTextType(keywords, value);
    addProperty(kw);
  }

  /// Set the PDF keywords property.
  void setKeywordsProperty(TextType kw) {
    addProperty(kw);
  }

  /// Set the PDFVersion.
  void setPDFVersion(String value) {
    TextType version = createTextType(pdfVersion, value);
    addProperty(version);
  }

  /// Set the PDFVersion property.
  void setPDFVersionProperty(TextType version) {
    addProperty(version);
  }

  /// Set the PDF Producer.
  void setProducer(String value) {
    TextType prod = createTextType(producer, value);
    addProperty(prod);
  }

  /// Set the PDF Producer property.
  void setProducerProperty(TextType prod) {
    addProperty(prod);
  }

  /// Get the PDF Keywords property.
  TextType? getKeywordsProperty() {
    AbstractField? tmp = getProperty(keywords);
    if (tmp is TextType) {
      return tmp;
    }
    return null;
  }

  /// Get the PDF Keywords property value (string).
  String? getKeywords() {
    AbstractField? tmp = getProperty(keywords);
    if (tmp is TextType) {
      return tmp.stringValue;
    }
    return null;
  }

  /// Get the PDFVersion property.
  TextType? getPDFVersionProperty() {
    AbstractField? tmp = getProperty(pdfVersion);
    if (tmp is TextType) {
      return tmp;
    }
    return null;
  }

  /// Get the PDFVersion property value (string).
  String? getPDFVersion() {
    AbstractField? tmp = getProperty(pdfVersion);
    if (tmp is TextType) {
      return tmp.stringValue;
    }
    return null;
  }

  /// Get the producer property.
  TextType? getProducerProperty() {
    AbstractField? tmp = getProperty(producer);
    if (tmp is TextType) {
      return tmp;
    }
    return null;
  }

  /// Get the producer property value (string).
  String? getProducer() {
    AbstractField? tmp = getProperty(producer);
    if (tmp is TextType) {
      return tmp.stringValue;
    }
    return null;
  }
}


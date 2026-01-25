/// Several constants used in XMP.
/// Ported from org.apache.xmpbox.XmpConstants
class XmpConstants {
  XmpConstants._();

  /// The RDF namespace URI reference.
  static const String rdfNamespace = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';

  /// The default xpacket header begin attribute.
  static const String defaultXpacketBegin = '\uFEFF';

  /// The default xpacket header id attribute.
  static const String defaultXpacketId = 'W5M0MpCehiHzreSzNTczkc9d';

  /// The default xpacket header encoding attribute.
  static const String defaultXpacketEncoding = 'UTF-8';

  /// The default xpacket data (XMP Data).
  static const String? defaultXpacketBytes = null;

  /// The default xpacket trailer end attribute.
  static const String defaultXpacketEnd = 'w';

  /// The default namespace prefix for RDF.
  static const String defaultRdfPrefix = 'rdf';

  /// The default local name for RDF.
  static const String defaultRdfLocalName = 'RDF';

  /// The list element name.
  static const String listName = 'li';

  /// The language attribute name.
  static const String langName = 'lang';

  /// The about attribute name.
  static const String aboutName = 'about';

  /// The Description element name.
  static const String descriptionName = 'Description';

  /// The resource attribute name.
  static const String resourceName = 'Resource';

  /// The parse type attribute name.
  static const String parseType = 'parseType';

  /// The default language code.
  static const String xDefault = 'x-default';
}


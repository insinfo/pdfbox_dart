import 'xmp_constants.dart';
import 'schema/xmp_schema.dart';
import 'schema/adobe_pdf_schema.dart';
import 'schema/dublin_core_schema.dart';
import 'schema/xmp_basic_schema.dart';
import 'schema/pdfa_identification_schema.dart';

/// Object representation of XMPMetaData.
/// 
/// Be CAREFUL: typically, metadata should contain only one schema for each type
/// (each NSURI). Retrieval of common schemas (like DublinCore) is based on this fact and take the first schema of this
/// type encountered. However, XmpBox allow you to place schemas of same type with different prefix.
/// 
/// Ported from org.apache.xmpbox.XMPMetadata
class XMPMetadata {
  String? _xpacketId;
  String? _xpacketBegin;
  String? _xpacketBytes;
  String? _xpacketEncoding;
  String _xpacketEndData = XmpConstants.defaultXpacketEnd;

  final List<XMPSchema> _schemas = [];

  // TODO: Implement TypeMapping
  // final TypeMapping _typeMapping;

  /// Constructor of an empty default XMPMetaData.
  XMPMetadata._() : this._full(
    XmpConstants.defaultXpacketBegin,
    XmpConstants.defaultXpacketId,
    XmpConstants.defaultXpacketBytes,
    XmpConstants.defaultXpacketEncoding,
  );

  /// Creates blank XMP doc with specified parameters.
  XMPMetadata._full(
    this._xpacketBegin,
    this._xpacketId,
    this._xpacketBytes,
    this._xpacketEncoding,
  );

  /// Creates blank XMP doc with default parameters.
  factory XMPMetadata.create() {
    return XMPMetadata._();
  }

  /// Creates blank XMP doc with specified parameters.
  factory XMPMetadata.createWithParams(
    String xpacketBegin,
    String xpacketId,
    String? xpacketBytes,
    String xpacketEncoding,
  ) {
    return XMPMetadata._full(xpacketBegin, xpacketId, xpacketBytes, xpacketEncoding);
  }

  // TODO: Implement TypeMapping
  // TypeMapping get typeMapping => _typeMapping;

  /// Get xpacketBytes.
  String? get xpacketBytes => _xpacketBytes;

  /// Get xpacket encoding.
  String? get xpacketEncoding => _xpacketEncoding;

  /// Get xpacket Begin.
  String? get xpacketBegin => _xpacketBegin;

  /// Get xpacket Id.
  String? get xpacketId => _xpacketId;

  /// Get all Schemas declared in this metadata representation.
  List<XMPSchema> getAllSchemas() {
    return List.from(_schemas);
  }

  /// Set special XPACKET END PI.
  set endXPacket(String data) => _xpacketEndData = data;

  /// Get XPACKET END PI.
  String get endXPacket => _xpacketEndData;

  /// Get the XMPSchema for the specified namespace.
  /// 
  /// Return the schema corresponding to this nsURI.
  /// BE CAREFUL: typically, Metadata should contain one schema for each type.
  /// This method returns the first schema encountered corresponding to this NSURI.
  /// Return null if unknown.
  XMPSchema? getSchema(String nsURI) {
    for (XMPSchema schema in _schemas) {
      if (schema.namespace == nsURI) {
        return schema;
      }
    }
    return null;
  }

  /// Return the schema corresponding to this nsURI and a prefix.
  /// 
  /// This method is here to treat metadata which embed more
  /// than one time the same schema. It permits to retrieve a specific schema with its prefix.
  XMPSchema? getSchemaWithPrefix(String prefix, String nsURI) {
    for (XMPSchema schema in _schemas) {
      if (schema.namespace == nsURI && schema.prefix == prefix) {
        return schema;
      }
    }
    return null;
  }

  /// Create and add an unspecified schema.
  XMPSchema createAndAddDefaultSchema(String nsPrefix, String nsURI) {
    XMPSchema schema = XMPSchema.full(this, nsURI, nsPrefix, null);
    schema.setAboutAsSimple("");
    addSchema(schema);
    return schema;
  }

  /// Add a schema to the current structure.
  void addSchema(XMPSchema obj) {
    _schemas.add(obj);
  }

  /// Remove a schema.
  void removeSchema(XMPSchema schema) {
    _schemas.remove(schema);
  }

  /// Removes all schemas defined.
  void clearSchemas() {
    _schemas.clear();
  }

  // --- Convenience methods for specific schemas ---

  /// Create and add a Dublin Core schema to this metadata.
  DublinCoreSchema createAndAddDublinCoreSchema() {
    DublinCoreSchema dc = DublinCoreSchema(this);
    dc.setAboutAsSimple("");
    addSchema(dc);
    return dc;
  }

  /// Get the Dublin Core schema.
  /// Returns null if not found.
  DublinCoreSchema? getDublinCoreSchema() {
    return getSchema(DublinCoreSchema.defaultNamespace) as DublinCoreSchema?;
  }

  /// Create and add an Adobe PDF schema to this metadata.
  AdobePDFSchema createAndAddAdobePDFSchema() {
    AdobePDFSchema pdf = AdobePDFSchema(this);
    pdf.setAboutAsSimple("");
    addSchema(pdf);
    return pdf;
  }

  /// Get the Adobe PDF schema.
  /// Returns null if not found.
  AdobePDFSchema? getAdobePDFSchema() {
    return getSchema(AdobePDFSchema.defaultNamespace) as AdobePDFSchema?;
  }

  /// Create and add an XMP Basic schema to this metadata.
  XMPBasicSchema createAndAddXMPBasicSchema() {
    XMPBasicSchema xmpB = XMPBasicSchema(this);
    xmpB.setAboutAsSimple("");
    addSchema(xmpB);
    return xmpB;
  }

  /// Get the XMP Basic schema.
  /// Returns null if not found.
  XMPBasicSchema? getXMPBasicSchema() {
    return getSchema(XMPBasicSchema.defaultNamespace) as XMPBasicSchema?;
  }

  /// Create and add a PDF/A Identification schema to this metadata.
  PDFAIdentificationSchema createAndAddPDFAIdentificationSchema() {
    PDFAIdentificationSchema pdfAId = PDFAIdentificationSchema(this);
    pdfAId.setAboutAsSimple("");
    addSchema(pdfAId);
    return pdfAId;
  }

  /// Get the PDF/A Identification schema.
  /// Returns null if not found.
  PDFAIdentificationSchema? getPDFAIdentificationSchema() {
    return getSchema(PDFAIdentificationSchema.defaultNamespace) as PDFAIdentificationSchema?;
  }
}


import 'dart:io' as io;
import 'dart:typed_data';
import '../../../io/exceptions.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_document.dart';
import '../../cos/cos_name.dart';
import '../../../io/random_access_read.dart';
import '../../../io/random_access_read_buffer.dart';
import '../../pdfwriter/cos_writer.dart';
import '../../pdfwriter/pdf_save_options.dart';
import '../pd_document.dart';
import 'fdf_catalog.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';
/// In-memory representation of the FDF document.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFDocument
/// Note: You need to call close() on this object when you are done using it.
class FDFDocument {
  FDFDocument(this._cosDocument, [this._source]);

  /// Creates an empty FDF document with an initialized catalog.
  FDFDocument.create()
      : _cosDocument = COSDocument(),
        _source = null {
    _cosDocument.headerVersion = '1.2';
    _cosDocument.setTrailer(COSDictionary());
    catalog = FDFCatalog();
  }

  /// Creates an FDF document from an XFDF XML string.
  factory FDFDocument.fromXmlString(String xml) {
    final document = XmlDocument.parse(xml);
    return FDFDocument.fromXmlDocument(document);
  }

  /// Creates an FDF document from an XFDF XML document.
  factory FDFDocument.fromXmlDocument(XmlDocument document) {
    final root = document.rootElement;
    if (root.name.local != 'xfdf') {
      throw IOException(
        "Error while importing xfdf document, root should be 'xfdf' and not '${root.name.local}'",
      );
    }
    final fdfDocument = FDFDocument.create();
    fdfDocument.catalog = FDFCatalog.fromXml(root);
    return fdfDocument;
  }

  final COSDocument _cosDocument;
  final RandomAccessRead? _source;
  bool _closed = false;

  /// This will get the low level document.
  /// Returns the document that this layer sits on top of.
  COSDocument get cosDocument => _cosDocument;

  /// This will get the FDF Catalog. This is guaranteed to not return null.
  /// Returns the documents /Root dictionary.
  FDFCatalog get catalog {
    final root = _cosDocument.trailer.getCOSDictionary(COSName.root);
    if (root != null) {
      return FDFCatalog(root);
    }
    final created = FDFCatalog();
    catalog = created;
    return created;
  }

  /// This will set the FDF catalog for this FDF document.
  /// [cat] The FDF catalog.
  set catalog(FDFCatalog value) {
    _cosDocument.trailer.setItem(COSName.root, value);
  }

  bool get isClosed => _closed;

  /// This will save this document to the filesystem as FDF.
  /// [fileName] The file to save as.
  /// Throws IOException if there is an error saving the document.
  Future<void> save(String fileName) async {
    await _saveBinaryFdf(fileName);
  }

  /// Save this document to a binary FDF byte buffer.
  Uint8List saveToBytes() {
    final buffer = RandomAccessReadWriteBuffer();
    final pdDocument = PDDocument.fromCOSDocument(_cosDocument);
    final writer = COSWriter(buffer, const PDFSaveOptions());
    writer.writeDocument(pdDocument);

    final length = buffer.length;
    buffer.seek(0);
    final bytes = Uint8List(length);
    if (length > 0) {
      buffer.readFully(bytes);
    }
    buffer.close();
    _patchFdfHeader(bytes);
    return bytes;
  }

  /// Saves the FDF document to the provided file.
  Future<void> saveFile(io.File file) async {
    await _saveBinaryFdf(file.path);
  }

  /// Saves the FDF document to an output sink.
  Future<void> saveToSink(io.IOSink output) async {
    output.add(saveToBytes());
    await output.flush();
  }

  /// This will save this document as XFDF to the filesystem.
  /// [fileName] The file to save as.
  /// Throws IOException if there is an error saving the document.
  Future<void> saveXFDF(String fileName) async {
    final file = io.File(fileName);
    await file.writeAsString(_buildXFDFXML());
  }

  /// Saves the XFDF document to an output sink.
  Future<void> saveXFDFToSink(io.IOSink output) async {
    output.write(_buildXFDFXML());
    await output.flush();
  }

  /// This will write this element as an XML document.
  /// [output] The stream to write the xml to.
  /// Throws IOException if there is an error writing the XML.
  void writeXML(StringSink output) {
    try {
      output.write(_buildXFDFXML());
    } catch (e) {
      throw IOException('Error writing FDF XML: $e');
    }
  }

  /// Builds the XFDF XML string.
  String _buildXFDFXML() {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    buffer.write('<xfdf xmlns="http://ns.adobe.com/xfdf/" xml:space="preserve">\n');
    catalog.writeXML(buffer);
    buffer.write('</xfdf>\n');
    return buffer.toString();
  }

  Future<void> _saveBinaryFdf(String fileName) async {
    final bytes = saveToBytes();
    final file = io.File(fileName);
    await file.writeAsBytes(bytes, flush: true);
  }

  void _patchFdfHeader(Uint8List bytes) {
    if (bytes.length < 8) {
      return;
    }
    if (bytes[0] == 0x25 /* % */ &&
        bytes[1] == 0x50 /* P */ &&
        bytes[2] == 0x44 /* D */ &&
        bytes[3] == 0x46 /* F */) {
      bytes[1] = 0x46; // F
      bytes[2] = 0x44; // D
      bytes[3] = 0x46; // F
    }
  }

  /// This will close the underlying COSDocument object.
  /// Throws IOException if there is an error releasing resources.
  void close() {
    if (_closed) {
      return;
    }
    _cosDocument.close();
    _source?.close();
    _closed = true;
  }
}


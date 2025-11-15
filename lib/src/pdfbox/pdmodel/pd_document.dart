import 'dart:io';
import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../../io/random_access_read_buffered_file.dart';
import '../../io/random_access_write.dart';
import '../pdfwriter/cos_writer.dart';
import '../pdfwriter/pdf_save_options.dart';
import 'encryption/pd_encryption.dart';
import 'encryption/access_permission.dart';
import 'encryption/standard_security_handler.dart';
import '../pdmodel/interactive/digitalsignature/external_signing_support.dart';
import '../pdmodel/interactive/digitalsignature/signing_support.dart';
import '../pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import '../pdfparser/pdf_parser.dart';
import 'pd_document_information.dart';
import 'pd_document_catalog.dart';
import 'pd_page.dart';
import 'pd_resources.dart';
import 'resource_cache.dart';
import 'pd_stream.dart';

/// High level representation of a PDF document.
class PDDocument {
  PDDocument._(this._document, this._catalog, this._resourceCache)
      : _accessPermission = AccessPermission.ownerAccessPermission();

  factory PDDocument() {
    final cosDocument = COSDocument();
    final pagesDict = COSDictionary()
      ..setName(COSName.type, 'Pages')
      ..setInt(COSName.count, 0);
    pagesDict[COSName.kids] = COSArray();

    final pagesObject = cosDocument.createObject(pagesDict);

    final catalogDict = COSDictionary()
      ..setName(COSName.type, 'Catalog')
      ..setItem(COSName.pages, pagesObject);
    final catalogObject = cosDocument.createObject(catalogDict);
    cosDocument.trailer[COSName.root] = catalogObject;

    final resourceCache = ResourceCache();
    final catalog = PDDocumentCatalog(cosDocument, resourceCache, catalogDict);
    final document = PDDocument._(cosDocument, catalog, resourceCache);
    document._accessPermission = AccessPermission.ownerAccessPermission();
    return document;
  }

  factory PDDocument.fromCOSDocument(COSDocument document) {
    final catalogDictionary = _requireCatalogDictionary(document);
    final resourceCache = ResourceCache();
    final catalog =
        PDDocumentCatalog(document, resourceCache, catalogDictionary);
    final pdDocument = PDDocument._(document, catalog, resourceCache);
    final encryptionDict = document.trailer.getCOSDictionary(COSName.encrypt);
    if (encryptionDict != null) {
      pdDocument._encryption = PDEncryption(encryptionDict);
      pdDocument._accessPermission =
          StandardSecurityHandler.permissionsFromEncryption(
              pdDocument._encryption!);
    } else {
      pdDocument._accessPermission = AccessPermission.ownerAccessPermission();
    }
    return pdDocument;
  }

  /// Loads a PDF document from a [RandomAccessRead] source using [PDFParser].
  ///
  /// The [source] is always closed after parsing, regardless of success.
  static PDDocument loadRandomAccess(RandomAccessRead source,
      {bool lenient = true}) {
    try {
      final parser = PDFParser(source);
      return parser.parse(lenient: lenient);
    } finally {
      source.close();
    }
  }

  /// Loads a PDF document from raw [bytes].
  static PDDocument loadFromBytes(Uint8List bytes, {bool lenient = true}) {
    final buffer = RandomAccessReadBuffer.fromBytes(bytes);
    return loadRandomAccess(buffer, lenient: lenient);
  }

  /// Loads a PDF document from a file at [path].
  static PDDocument loadFile(String path, {bool lenient = true}) {
    final reader = RandomAccessReadBufferedFile(path);
    return loadRandomAccess(reader, lenient: lenient);
  }

  /// Loads a PDF document from an open [file].
  static PDDocument loadFromFile(File file, {bool lenient = true}) {
    final reader = RandomAccessReadBufferedFile.fromFile(file);
    return loadRandomAccess(reader, lenient: lenient);
  }

  final COSDocument _document;
  final PDDocumentCatalog _catalog;
  final ResourceCache _resourceCache;
  bool _closed = false;
  PDDocumentInformation? _documentInformation;
  PDEncryption? _encryption;
  AccessPermission _accessPermission;

  COSDocument get cosDocument => _document;

  PDDocumentCatalog get documentCatalog => _catalog;

  ResourceCache get resourceCache => _resourceCache;

  PDOutlineRoot? get documentOutline => _catalog.documentOutline;

  set documentOutline(PDOutlineRoot? outline) =>
      _catalog.documentOutline = outline;

  String get version => _document.headerVersion;

  set version(String value) {
    _ensureOpen();
    _document.headerVersion = value;
  }

  int get numberOfPages => documentCatalog.pages.count;

  PDPage getPage(int pageIndex) => documentCatalog.pages[pageIndex];

  void addPage(PDPage page) {
    _ensureOpen();
    _preparePage(page);
    documentCatalog.pages.addPage(page);
  }

  void insertPage(int pageIndex, PDPage page) {
    _ensureOpen();
    _preparePage(page);
    documentCatalog.pages.insertPage(pageIndex, page);
  }

  bool removePage(PDPage page) {
    _ensureOpen();
    return documentCatalog.pages.removePage(page);
  }

  PDPage removePageAt(int pageIndex) {
    _ensureOpen();
    return documentCatalog.pages.removePageAt(pageIndex);
  }

  int indexOfPage(PDPage page) => documentCatalog.pages.indexOf(page);

  Uint8List saveToBytes({PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    final buffer = RandomAccessReadWriteBuffer();
    final writer = COSWriter(buffer, options);
    writer.writeDocument(this);
    final length = buffer.length;
    buffer.seek(0);
    final data = Uint8List(length);
    if (length > 0) {
      buffer.readFully(data);
    }
    buffer.close();
    return data;
  }

  void save(RandomAccessWrite target,
      {PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    final writer = COSWriter(target, options);
    writer.writeDocument(this);
  }

  void saveIncremental(
    RandomAccessRead original,
    RandomAccessWrite target, {
    PDFSaveOptions options = const PDFSaveOptions(),
  }) {
    _ensureOpen();
    final writer = COSWriter(target, options);
    writer.writeIncremental(this, original);
  }

  ExternalSigningSupport saveIncrementalForExternalSigning(
    RandomAccessRead original,
    RandomAccessWrite target, {
    PDFSaveOptions options = const PDFSaveOptions(),
  }) {
    _ensureOpen();
    final buffer = RandomAccessReadWriteBuffer();
    final writer = COSWriter(buffer, options);
    final context = writer.prepareIncrementalSigning(this, original, target);
    return SigningSupport(context);
  }

  void close() {
    if (_closed) {
      return;
    }
    _document.close();
    _closed = true;
  }

  bool get isClosed => _closed;

  PDDocumentInformation get documentInformation {
    if (_documentInformation != null) {
      return _documentInformation!;
    }
    final infoDict = _document.trailer.getCOSDictionary(COSName.info);
    if (infoDict != null) {
      _documentInformation = PDDocumentInformation(dictionary: infoDict);
    } else {
      final info = PDDocumentInformation();
      _document.trailer[COSName.info] = info.cosObject;
      _documentInformation = info;
    }
    return _documentInformation!;
  }

  set documentInformation(PDDocumentInformation information) {
    _documentInformation = information;
    _document.trailer[COSName.info] = information.cosObject;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDDocument is closed');
    }
  }

  void _preparePage(PDPage page) {
    final dict = page.cosObject;

    page.resourceCache ??= _resourceCache;

    if (dict.getDictionaryObject(COSName.resources) == null) {
      page.resources = PDResources(null, _resourceCache);
    }

    final streams = page.contentStreams.toList();
    if (streams.isEmpty) {
      page.setContentStream(PDStream.fromBytes(Uint8List(0)));
    } else {
      for (final stream in streams) {
        if (stream.encodedBytes == null) {
          stream.encodedBytes = Uint8List(0);
        }
      }
    }
  }

  static COSDictionary _requireCatalogDictionary(COSDocument document) {
    final root = document.trailer.getDictionaryObject(COSName.root);
    if (root is COSDictionary) {
      return root;
    }
    throw StateError('COSDocument trailer missing /Root dictionary');
  }

  PDEncryption? get encryption => _encryption;

  /// Associates the supplied encryption dictionary with the document trailer.
  void setEncryptionDictionary(PDEncryption encryption) {
    _encryption = encryption;
    final cosDocument = _document;
    final encryptionDict = encryption.cosObject;
    COSObject trailerObject;

    final currentKey = encryptionDict.key;
    if (currentKey == null) {
      trailerObject = cosDocument.createObject(encryptionDict);
    } else {
      final existing = cosDocument.getObject(currentKey);
      if (existing == null) {
        trailerObject = COSObject.fromKey(currentKey, encryptionDict);
        cosDocument.addObject(trailerObject);
      } else {
        if (!identical(existing.object, encryptionDict)) {
          existing.object = encryptionDict;
        }
        trailerObject = existing;
      }
    }

    cosDocument.trailer[COSName.encrypt] = trailerObject;
  }

  /// Permissions granted to the caller for the current encrypted document.
  AccessPermission get currentAccessPermission => _accessPermission;
}

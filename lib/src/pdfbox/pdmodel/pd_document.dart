import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../../io/random_access_write.dart';
import '../pdfwriter/pdf_save_options.dart';
import '../pdfwriter/simple_pdf_writer.dart';
import 'pd_document_information.dart';
import 'pd_document_catalog.dart';
import 'pd_page.dart';
import 'pd_resources.dart';
import 'pd_stream.dart';

/// High level representation of a PDF document.
class PDDocument {
  PDDocument._(this._document, this._catalog);

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

    return PDDocument._(cosDocument, PDDocumentCatalog(cosDocument, catalogDict));
  }

  factory PDDocument.fromCOSDocument(COSDocument document) {
    final catalogDictionary = _requireCatalogDictionary(document);
    return PDDocument._(document, PDDocumentCatalog(document, catalogDictionary));
  }

  final COSDocument _document;
  final PDDocumentCatalog _catalog;
  bool _closed = false;
  PDDocumentInformation? _documentInformation;

  COSDocument get cosDocument => _document;

  PDDocumentCatalog get documentCatalog => _catalog;

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
    final writer = SimplePdfWriter(this, options);
    return writer.write();
  }

  void save(RandomAccessWrite target, {PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    target.clear();
    target.writeBytes(saveToBytes(options: options));
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

    if (dict.getDictionaryObject(COSName.resources) == null) {
      page.resources = PDResources();
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
}

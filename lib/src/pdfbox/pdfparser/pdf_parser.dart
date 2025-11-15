import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_document.dart';
import '../cos/cos_object.dart';
import '../pdmodel/pd_document.dart';
import 'cos_parser.dart';

class PDFParser extends COSParser {
  PDFParser(RandomAccessRead source)
      : _logger = Logger('pdfbox.PDFParser'),
        super(source);

  final Logger _logger;
  String? _documentVersion;

  String? get documentVersion => _documentVersion;

  PDDocument parse({bool lenient = true}) {
    setLenient(lenient);
    final headerOk = _parsePDFHeader() || _parseFDFHeader();
    if (!headerOk) {
      const message = "Error: Header doesn't contain versioninfo";
      if (isLenient) {
        _logger.warning(message);
      } else {
        throw IOException(message);
      }
    }

    source.seek(0);
    final cosDocument = parseDocument();
    cosDocument.headerVersion = _documentVersion ?? '1.4';

    var catalogDict = _resolveRootDictionary(cosDocument);
    if (catalogDict == null && isLenient) {
      catalogDict = _recoverCatalogFromBruteForce(cosDocument);
    }
    if (catalogDict == null) {
      throw IOException('Missing root object specification in trailer.');
    }
    if (isLenient && !catalogDict.containsKey(COSName.type)) {
      catalogDict[COSName.type] = COSName.get('Catalog');
    }

    _checkPages(catalogDict);

    final document = createDocument(cosDocument);
    initialParseDone = true;
    return document;
  }

  PDDocument createDocument(COSDocument cosDocument) {
    return PDDocument.fromCOSDocument(cosDocument);
  }

  COSDictionary? _recoverCatalogFromBruteForce(COSDocument cosDocument) {
    _logger.warning(
      'Missing document catalog; attempting brute-force recovery in lenient mode',
    );
    try {
      final previousDocument = document;
      document = cosDocument;
      try {
        source.seek(0);
        rebuildDocumentFromBruteForce(cosDocument);
      } finally {
        document = previousDocument;
      }
      cosDocument.startXref = 0;
      cosDocument.markAllClean();
      return _resolveRootDictionary(cosDocument);
    } on IOException catch (exception, stackTrace) {
      _logger.warning(
        'Brute-force recovery failed to rebuild catalog',
        exception,
        stackTrace,
      );
      return null;
    }
  }

  bool _parsePDFHeader() => _parseHeader('%PDF-', defaultVersion: '1.4');

  bool _parseFDFHeader() => _parseHeader('%FDF-', defaultVersion: '1.0');

  bool _parseHeader(String marker, {required String defaultVersion}) {
    final version = parseHeader(marker, defaultVersion: defaultVersion);
    if (version == null) {
      return false;
    }
    _documentVersion = version;
    return true;
  }

  void _checkPages(COSDictionary rootDictionary) {
    final pages = rootDictionary.getCOSDictionary(COSName.pages);
    if (pages == null) {
      if (isLenient) {
        final placeholder = COSDictionary()
          ..setName(COSName.type, 'Pages')
          ..setInt(COSName.count, 0)
          ..setItem(COSName.kids, COSArray());
        rootDictionary[COSName.pages] = placeholder;
        return;
      }
      throw IOException('Missing /Pages dictionary in catalog.');
    }

    if (!pages.containsKey(COSName.type)) {
      if (isLenient) {
        pages.setName(COSName.type, 'Pages');
      } else {
        throw IOException('Pages dictionary missing /Type entry.');
      }
    }

    if (pages.getCOSArray(COSName.kids) == null) {
      if (isLenient) {
        pages[COSName.kids] = COSArray();
      } else {
        throw IOException('Page tree root must define /Kids array.');
      }
    }

    if (pages.getInt(COSName.count) == null) {
      if (isLenient) {
        pages.setInt(COSName.count, 0);
      } else {
        throw IOException('Page tree root missing /Count entry.');
      }
    }
  }

  COSDictionary? _resolveRootDictionary(COSDocument cosDocument) {
    final direct = cosDocument.trailer.getCOSDictionary(COSName.root);
    if (direct != null) {
      return direct;
    }
    final rootEntry = cosDocument.trailer[COSName.root];
    if (rootEntry is COSObject) {
      final key = rootEntry.key;
      if (key != null) {
        final resolved = cosDocument.getObject(key)?.object;
        if (resolved is COSDictionary) {
          return resolved;
        }
      }
    }
    for (final object in cosDocument.objects) {
      final value = object.object;
      if (value is COSDictionary) {
        final type = value.getNameAsString(COSName.type);
        if (type == 'Catalog') {
          return value;
        }
      }
    }
    return null;
  }
}

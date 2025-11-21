import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:archive/archive.dart';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../cos/cos_stream.dart';
import '../pdmodel/pd_stream.dart';
import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/common/pd_rectangle.dart';
import '../pdmodel/graphics/form/pd_form_xobject.dart';
import '../util/matrix.dart';
import 'pdf_clone_utility.dart';

/// Adds an overlay to an existing PDF document.
/// 
/// Based on code contributed by Balazs Jerk.
class Overlay {
  static final Logger _logger = Logger('pdfbox.Overlay');

  /// Possible location of the overlaid pages: foreground or background.
  OverlayPosition position;

  _LayoutPage? _defaultOverlayPage;
  final Map<int, _LayoutPage> _rotatedDefaultOverlayPagesMap = {};
  _LayoutPage? _firstPageOverlayPage;
  _LayoutPage? _lastPageOverlayPage;
  _LayoutPage? _oddPageOverlayPage;
  _LayoutPage? _evenPageOverlayPage;

  final Set<PDDocument> _openDocumentsSet = {};
  Map<int, _LayoutPage> _specificPageOverlayLayoutPageMap = {};

  String? _inputFileName;
  PDDocument? _inputPDFDocument;

  String? _defaultOverlayFilename;
  PDDocument? _defaultOverlayDocument;

  String? _firstPageOverlayFilename;
  PDDocument? _firstPageOverlayDocument;

  String? _lastPageOverlayFilename;
  PDDocument? _lastPageOverlayDocument;
  
  String? _allPagesOverlayFilename;
  PDDocument? _allPagesOverlayDocument;
  
  String? _oddPageOverlayFilename;
  PDDocument? _oddPageOverlayDocument;
  
  String? _evenPageOverlayFilename;
  PDDocument? _evenPageOverlayDocument;

  int _numberOfOverlayPages = 0;
  bool _useAllOverlayPages = false;
  bool _adjustRotation = false;

  Overlay({this.position = OverlayPosition.background});

  /// This will add overlays to a document.
  ///
  /// [specificPageOverlayMap] Optional map of overlay files of which the first page will be
  /// used for specific pages of the input document. The page numbers are 1-based. The map must be
  /// empty (but not null) if no specific mappings are used.
  ///
  /// Returns The modified input PDF document, which has to be saved and closed by the caller. If
  /// the input document was passed by [setInputPDF] then it is that object that is returned.
  PDDocument overlay(Map<int, String> specificPageOverlayMap) {
    final layouts = <String, _LayoutPage>{};
    _loadPDFs();
    for (final entry in specificPageOverlayMap.entries) {
      final path = entry.value;
      var layoutPage = layouts[path];
      if (layoutPage == null) {
        final doc = _loadPDF(path);
        layoutPage = _createLayoutPageFromDocument(doc);
        layouts[path] = layoutPage;
        _openDocumentsSet.add(doc);
      }
      _specificPageOverlayLayoutPageMap[entry.key] = layoutPage;
    }
    _processPages(_inputPDFDocument!);
    return _inputPDFDocument!;
  }

  /// This will add overlays documents to a document. If you created the overlay documents with
  /// subsetted fonts, you need to save them first so that the subsetting gets done.
  ///
  /// [specificPageOverlayDocumentMap] Optional map of overlay documents for specific pages. The
  /// page numbers are 1-based. The map must be empty (but not null) if no specific mappings are
  /// used.
  ///
  /// Returns The modified input PDF document, which has to be saved and closed by the caller. If
  /// the input document was passed by [setInputPDF] then it is that object that is returned.
  PDDocument overlayDocuments(Map<int, PDDocument> specificPageOverlayDocumentMap) {
    _loadPDFs();
    for (final entry in specificPageOverlayDocumentMap.entries) {
      final doc = entry.value;
      _specificPageOverlayLayoutPageMap[entry.key] = _createLayoutPageFromDocument(doc);
    }
    _processPages(_inputPDFDocument!);
    return _inputPDFDocument!;
  }

  /// Close all input documents which were used for the overlay and opened by this class.
  void close() {
    _defaultOverlayDocument?.close();
    _firstPageOverlayDocument?.close();
    _lastPageOverlayDocument?.close();
    _allPagesOverlayDocument?.close();
    _oddPageOverlayDocument?.close();
    _evenPageOverlayDocument?.close();
    for (final doc in _openDocumentsSet) {
      doc.close();
    }
    _openDocumentsSet.clear();
    _specificPageOverlayLayoutPageMap.clear();
    _rotatedDefaultOverlayPagesMap.clear();
  }

  void _loadPDFs() {
    // input PDF
    if (_inputFileName != null) {
      _inputPDFDocument = _loadPDF(_inputFileName!);
    }
    if (_inputPDFDocument == null) {
      throw ArgumentError("No input document");
    }
    // default overlay PDF
    if (_defaultOverlayFilename != null) {
      _defaultOverlayDocument = _loadPDF(_defaultOverlayFilename!);
    }
    if (_defaultOverlayDocument != null) {
      _defaultOverlayPage = _createLayoutPageFromDocument(_defaultOverlayDocument!);
    }
    // first page overlay PDF
    if (_firstPageOverlayFilename != null) {
      _firstPageOverlayDocument = _loadPDF(_firstPageOverlayFilename!);
    }
    if (_firstPageOverlayDocument != null) {
      _firstPageOverlayPage = _createLayoutPageFromDocument(_firstPageOverlayDocument!);
    }
    // last page overlay PDF
    if (_lastPageOverlayFilename != null) {
      _lastPageOverlayDocument = _loadPDF(_lastPageOverlayFilename!);
    }
    if (_lastPageOverlayDocument != null) {
      _lastPageOverlayPage = _createLayoutPageFromDocument(_lastPageOverlayDocument!);
    }
    // odd pages overlay PDF
    if (_oddPageOverlayFilename != null) {
      _oddPageOverlayDocument = _loadPDF(_oddPageOverlayFilename!);
    }
    if (_oddPageOverlayDocument != null) {
      _oddPageOverlayPage = _createLayoutPageFromDocument(_oddPageOverlayDocument!);
    }
    // even pages overlay PDF
    if (_evenPageOverlayFilename != null) {
      _evenPageOverlayDocument = _loadPDF(_evenPageOverlayFilename!);
    }
    if (_evenPageOverlayDocument != null) {
      _evenPageOverlayPage = _createLayoutPageFromDocument(_evenPageOverlayDocument!);
    }
    // all pages overlay PDF
    if (_allPagesOverlayFilename != null) {
      _allPagesOverlayDocument = _loadPDF(_allPagesOverlayFilename!);
    }
    if (_allPagesOverlayDocument != null) {
      _specificPageOverlayLayoutPageMap = _createPageOverlayLayoutPageMap(_allPagesOverlayDocument!);
      _useAllOverlayPages = true;
      _numberOfOverlayPages = _specificPageOverlayLayoutPageMap.length;
    }
  }
  
  PDDocument _loadPDF(String pdfName) {
    return PDDocument.loadFile(pdfName);
  }

  _LayoutPage _createLayoutPageFromDocument(PDDocument doc) {
    return _createLayoutPage(doc.getPage(0));
  }

  _LayoutPage _createLayoutPage(PDPage page) {
    final contents = page.cosObject.getDictionaryObject(COSName.contents);
    var resources = page.resources;
    // ignore: unnecessary_null_comparison
    if (resources == null) {
      resources = PDResources();
    }
    return _LayoutPage(
      page.mediaBox!,
      _createCombinedContentStream(contents),
      resources.cosObject,
      page.rotation,
    );
  }
  
  Map<int, _LayoutPage> _createPageOverlayLayoutPageMap(PDDocument doc) {
    int i = 0;
    final pageTree = doc.documentCatalog.pages;
    final layoutPages = <int, _LayoutPage>{};
    // PDPageTree in Dart is not directly iterable like Java's, need to check implementation
    // Assuming PDPageTree implements Iterable<PDPage> or has a way to iterate
    // In my port PDPageTree has `count` and `operator []`.
    for (var j = 0; j < pageTree.count; j++) {
      layoutPages[i] = _createLayoutPage(pageTree[j]);
      i++;
    }
    return layoutPages;
  }
  
  COSStream _createCombinedContentStream(COSBase? contents) {
    final contentStreams = _createContentStreamList(contents);
    // concatenate streams
    final builder = BytesBuilder();
    for (final contentStream in contentStreams) {
      final bytes = contentStream.decode();
      if (bytes != null) {
        builder.add(bytes);
      }
    }
    
    final concatenatedBytes = builder.toBytes();
    final compressedBytes = ZLibEncoder().encode(concatenatedBytes);
    
    final concatStream = COSStream();
    concatStream.data = Uint8List.fromList(compressedBytes);
    concatStream[COSName.filter] = COSName.flateDecode;
    
    return concatStream;
  }

  List<COSStream> _createContentStreamList(COSBase? contents) {
    if (contents == null) {
      return [];
    }
    if (contents is COSStream) {
      return [contents];
    }

    final contentStreams = <COSStream>[];
    if (contents is COSArray) {
      for (final item in contents) {
        contentStreams.addAll(_createContentStreamList(item));
      }
    } else if (contents is COSObject) {
      contentStreams.addAll(_createContentStreamList(contents.object));
    } else {
      throw StateError("Unknown content type: ${contents.runtimeType}");
    }
    return contentStreams;
  }

  void _processPages(PDDocument document) {
    int pageCounter = 0;
    final cloner = PDFCloneUtility(document);
    final pageTree = document.documentCatalog.pages;
    final numberOfPages = pageTree.count;
    
    for (var i = 0; i < numberOfPages; i++) {
      final page = pageTree[i];
      pageCounter++;
      final layoutPage = _getLayoutPage(pageCounter, numberOfPages);
      if (layoutPage == null) {
        continue;
      }
      final pageDictionary = page.cosObject;
      final originalContent = pageDictionary.getDictionaryObject(COSName.contents);
      final newContentArray = COSArray();
      switch (position) {
        case OverlayPosition.foreground:
          // save state
          newContentArray.add(_createStream("q\n"));
          _addOriginalContent(originalContent, newContentArray);
          // restore state
          newContentArray.add(_createStream("Q\n"));
          // overlay content last
          _overlayPage(page, layoutPage, newContentArray, cloner);
          break;
        case OverlayPosition.background:
          // overlay content first
          _overlayPage(page, layoutPage, newContentArray, cloner);

          _addOriginalContent(originalContent, newContentArray);
          break;
      }
      pageDictionary[COSName.contents] = newContentArray;
    }
  }

  void _addOriginalContent(COSBase? contents, COSArray contentArray) {
    if (contents == null) {
      return;
    }

    if (contents is COSStream) {
      contentArray.add(contents);
    } else if (contents is COSArray) {
      for (final item in contents) {
        contentArray.add(item);
      }
    } else {
      throw StateError("Unknown content type: ${contents.runtimeType}");
    }
  }

  void _overlayPage(PDPage page, _LayoutPage layoutPage, COSArray array,
      PDFCloneUtility cloner) {
    var resources = page.resources;
    // ignore: unnecessary_null_comparison
    if (resources == null) {
      resources = PDResources();
      page.resources = resources;
    }
    final overlayFormXObject = _createOverlayFormXObject(layoutPage, cloner);
    final formXObjectId = resources.add(overlayFormXObject); // Modified PDResources.add returns COSName
    array.add(_createOverlayStream(page, layoutPage, formXObjectId));
  }

  _LayoutPage? _getLayoutPage(int pageNumber, int numberOfPages) {
    _LayoutPage? layoutPage;
    if (!_useAllOverlayPages && _specificPageOverlayLayoutPageMap.containsKey(pageNumber)) {
      layoutPage = _specificPageOverlayLayoutPageMap[pageNumber];
    } else if ((pageNumber == 1) && (_firstPageOverlayPage != null)) {
      layoutPage = _firstPageOverlayPage;
    } else if ((pageNumber == numberOfPages) && (_lastPageOverlayPage != null)) {
      layoutPage = _lastPageOverlayPage;
    } else if ((pageNumber % 2 == 1) && (_oddPageOverlayPage != null)) {
      layoutPage = _oddPageOverlayPage;
    } else if ((pageNumber % 2 == 0) && (_evenPageOverlayPage != null)) {
      layoutPage = _evenPageOverlayPage;
    } else if (_defaultOverlayPage != null) {
      layoutPage = _defaultOverlayPage;

      if (_adjustRotation) {
        final page = _inputPDFDocument!.getPage(pageNumber - 1);
        final rotation = page.rotation;
        if (rotation != 0) {
          return _createAdjustedLayoutPage(rotation);
        }
      }
    } else if (_useAllOverlayPages) {
      final usePageNum = (pageNumber - 1) % _numberOfOverlayPages;
      layoutPage = _specificPageOverlayLayoutPageMap[usePageNum];
    }
    return layoutPage;
  }

  _LayoutPage _createAdjustedLayoutPage(int rotation) {
    var rotatedLayoutPage = _rotatedDefaultOverlayPagesMap[rotation];
    if (rotatedLayoutPage == null) {
      // createLayoutPage must be called because we can't reuse the COSStream
      rotatedLayoutPage = _createLayoutPage(_defaultOverlayDocument!.getPage(0));
      final newRotation = (rotatedLayoutPage.overlayRotation - rotation + 360) % 360;
      rotatedLayoutPage.overlayRotation = newRotation;
      _rotatedDefaultOverlayPagesMap[rotation] = rotatedLayoutPage;
    }
    return rotatedLayoutPage;
  }

  PDFormXObject _createOverlayFormXObject(_LayoutPage layoutPage, PDFCloneUtility cloner) {
    final xobjForm = PDFormXObject(PDStream(layoutPage.overlayCOSStream));
    xobjForm.resources = PDResources(
        cloner.cloneForNewDocument(layoutPage.overlayResources) as COSDictionary);
    xobjForm.formType = 1;
    xobjForm.boundingBox = PDRectangle.fromCOSArray(layoutPage.overlayMediaBox.toCOSArray()); // createRetranslatedRectangle?
    // Java: layoutPage.overlayMediaBox.createRetranslatedRectangle()
    // PDRectangle.createRetranslatedRectangle() returns a new rectangle with x,y = 0,0 and same w,h.
    // I should check if PDRectangle has this method or implement it manually.
    // xobjForm.setBBox(new PDRectangle(0, 0, width, height));
    
    final bbox = layoutPage.overlayMediaBox;
    xobjForm.boundingBox = PDRectangle(0, 0, bbox.width, bbox.height);

    final at = Matrix();
    switch (layoutPage.overlayRotation) {
      case 90:
        at.translate(0, layoutPage.overlayMediaBox.width);
        at.rotate(3 * math.pi / 2); // 270
        break;
      case 180:
        at.translate(layoutPage.overlayMediaBox.width, layoutPage.overlayMediaBox.height);
        at.rotate(math.pi); // 180
        break;
      case 270:
        at.translate(layoutPage.overlayMediaBox.height, 0);
        at.rotate(math.pi / 2); // 90
        break;
      default:
        break;
    }
    xobjForm.matrix = at;
    return xobjForm;
  }

  COSStream _createOverlayStream(PDPage page, _LayoutPage layoutPage, COSName xObjectId) {
    // create a new content stream that executes the XObject content
    final overlayStream = StringBuffer();
    overlayStream.write("q\nq\n");
    
    // PDRectangle overlayMediaBox = new PDRectangle(layoutPage.overlayMediaBox.getCOSArray());
    var overlayMediaBox = PDRectangle.fromCOSArray(layoutPage.overlayMediaBox.toCOSArray());
    
    if (layoutPage.overlayRotation == 90 || layoutPage.overlayRotation == 270) {
      // Swap width and height logic from Java
      // overlayMediaBox.setLowerLeftX(layoutPage.overlayMediaBox.getLowerLeftY());
      // overlayMediaBox.setLowerLeftY(layoutPage.overlayMediaBox.getLowerLeftX());
      // overlayMediaBox.setUpperRightX(layoutPage.overlayMediaBox.getUpperRightY());
      // overlayMediaBox.setUpperRightY(layoutPage.overlayMediaBox.getUpperRightX());
      // This effectively swaps dimensions but keeps position?
      // Actually it seems to just swap X and Y coordinates.
      
      overlayMediaBox = PDRectangle(
          layoutPage.overlayMediaBox.lowerLeftY,
          layoutPage.overlayMediaBox.lowerLeftX,
          layoutPage.overlayMediaBox.upperRightY,
          layoutPage.overlayMediaBox.upperRightX
      );
    }
    
    final at = calculateAffineTransform(page, overlayMediaBox);
    // double[] flatmatrix = new double[6]; at.getMatrix(flatmatrix);
    // Matrix values: a b 0 c d 0 e f 1
    // flatmatrix: a b c d e f (m00 m10 m01 m11 m02 m12)
    
    overlayStream.write(_float2String(at.getValue(0, 0))); // a
    overlayStream.write(' ');
    overlayStream.write(_float2String(at.getValue(0, 1))); // b
    overlayStream.write(' ');
    overlayStream.write(_float2String(at.getValue(1, 0))); // c
    overlayStream.write(' ');
    overlayStream.write(_float2String(at.getValue(1, 1))); // d
    overlayStream.write(' ');
    overlayStream.write(_float2String(at.getValue(2, 0))); // e
    overlayStream.write(' ');
    overlayStream.write(_float2String(at.getValue(2, 1))); // f
    overlayStream.write(" cm\n");

    overlayStream.write(" /");
    overlayStream.write(xObjectId.name);
    overlayStream.write(" Do Q\nQ\n");
    return _createStream(overlayStream.toString());
  }

  /// Calculate the transform to be used when positioning the overlay.
  Matrix calculateAffineTransform(PDPage page, PDRectangle overlayMediaBox) {
    final at = Matrix();
    final pageMediaBox = page.mediaBox!;
    final hShift = pageMediaBox.lowerLeftX + (pageMediaBox.width - overlayMediaBox.width) / 2.0;
    final vShift = pageMediaBox.lowerLeftY + (pageMediaBox.height - overlayMediaBox.height) / 2.0;
    _logger.fine("Overlay position: ($hShift,$vShift)");
    at.translate(hShift, vShift);
    return at;
  }

  String _float2String(double floatValue) {
    // Dart double to string is usually fine, but let's mimic Java's BigDecimal logic if needed.
    // Java code removes trailing "0" but keeps ".0" if it was an integer.
    // Dart's toString() handles this reasonably well (e.g. 1.0 -> "1.0", 1.5 -> "1.5").
    // But Java code:
    // if (stringValue.indexOf('.') > -1 && !stringValue.endsWith(".0"))
    // {
    //     while (stringValue.endsWith("0") && !stringValue.endsWith(".0"))
    //     {
    //         stringValue = stringValue.substring(0,stringValue.length()-1);
    //     }
    // }
    // This removes trailing zeros like "1.500" -> "1.5". Dart does this automatically.
    return floatValue.toString();
  }
  
  COSStream _createStream(String content) {
    final stream = COSStream();
    final bytes = Uint8List.fromList(content.codeUnits); // ISO_8859_1 approximation
    if (content.length > 20) {
        stream.data = Uint8List.fromList(ZLibEncoder().encode(bytes));
        stream[COSName.filter] = COSName.flateDecode;
    } else {
        stream.data = bytes;
    }
    return stream;
  }

  void setOverlayPosition(OverlayPosition overlayPosition) {
    position = overlayPosition;
  }

  set inputFileName(String? inputFile) {
    _inputFileName = inputFile;
  }

  set inputPDF(PDDocument? inputPDF) {
    _inputPDFDocument = inputPDF;
  }

  String? get inputFile => _inputFileName;

  set defaultOverlayFile(String? defaultOverlayFile) {
    _defaultOverlayFilename = defaultOverlayFile;
  }

  set defaultOverlayPDF(PDDocument? defaultOverlayPDF) {
    _defaultOverlayDocument = defaultOverlayPDF;
  }

  String? get defaultOverlayFile => _defaultOverlayFilename;

  set firstPageOverlayFile(String? firstPageOverlayFile) {
    _firstPageOverlayFilename = firstPageOverlayFile;
  }

  set firstPageOverlayPDF(PDDocument? firstPageOverlayPDF) {
    _firstPageOverlayDocument = firstPageOverlayPDF;
  }

  set lastPageOverlayFile(String? lastPageOverlayFile) {
    _lastPageOverlayFilename = lastPageOverlayFile;
  }

  set lastPageOverlayPDF(PDDocument? lastPageOverlayPDF) {
    _lastPageOverlayDocument = lastPageOverlayPDF;
  }

  set allPagesOverlayFile(String? allPagesOverlayFile) {
    _allPagesOverlayFilename = allPagesOverlayFile;
  }

  set allPagesOverlayPDF(PDDocument? allPagesOverlayPDF) {
    _allPagesOverlayDocument = allPagesOverlayPDF;
  }

  set oddPageOverlayFile(String? oddPageOverlayFile) {
    _oddPageOverlayFilename = oddPageOverlayFile;
  }

  set oddPageOverlayPDF(PDDocument? oddPageOverlayPDF) {
    _oddPageOverlayDocument = oddPageOverlayPDF;
  }

  set evenPageOverlayFile(String? evenPageOverlayFile) {
    _evenPageOverlayFilename = evenPageOverlayFile;
  }

  set evenPageOverlayPDF(PDDocument? evenPageOverlayPDF) {
    _evenPageOverlayDocument = evenPageOverlayPDF;
  }

  set adjustRotation(bool adjustRotation) {
    _adjustRotation = adjustRotation;
  }
}

enum OverlayPosition {
  foreground,
  background
}

class _LayoutPage {
  final PDRectangle overlayMediaBox;
  final COSStream overlayCOSStream;
  final COSDictionary overlayResources;
  int overlayRotation;

  _LayoutPage(this.overlayMediaBox, this.overlayCOSStream, this.overlayResources, this.overlayRotation);
}

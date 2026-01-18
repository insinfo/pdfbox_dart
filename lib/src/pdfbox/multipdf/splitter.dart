import 'dart:math';

import 'package:logging/logging.dart';

import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';

import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_document_information.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/interactive/annotation/pd_annotation.dart';
import '../pdmodel/interactive/annotation/pd_annotation_factory.dart';
import 'pdf_clone_utility.dart';

/// Split a document into several other documents.
class Splitter {
  static final Logger _logger = Logger('pdfbox.Splitter');

  PDDocument? _sourceDocument;
  PDDocument? _currentDestinationDocument;

  int _splitLength = 1;
  int _startPage = -2147483648; // Integer.MIN_VALUE
  int _endPage = 2147483647; // Integer.MAX_VALUE
  List<PDDocument>? _destinationDocuments;
  Map<COSDictionary, COSDictionary>? _pageDictMap;
  List<Map<COSDictionary, COSDictionary>>? _pageDictMaps;
  Map<COSDictionary, COSDictionary>? _annotDictMap;
  List<Map<COSDictionary, COSDictionary>>? _annotDictMaps;

  int _currentPageNumber = 0;

  /// This will take a document and split into several other documents.
  ///
  /// [document] The document to split.
  ///
  /// Returns a list of all the split documents. These should all be saved before closing any
  /// documents, including the source document. Any further operations should be made after
  /// reloading them, to avoid problems due to resource sharing. For the same reason, they should
  /// not be saved with encryption.
  List<PDDocument> split(PDDocument document) {
    // reset the currentPageNumber for a case if the split method will be used several times
    _currentPageNumber = 0;
    _destinationDocuments = <PDDocument>[];
    _sourceDocument = document;
    _pageDictMaps = <Map<COSDictionary, COSDictionary>>[];
    _annotDictMaps = <Map<COSDictionary, COSDictionary>>[];

    _processPages();

    // TODO: cloneStructureTree and fixDestinations

    return _destinationDocuments!;
  }

  /// This will tell the splitting algorithm where to split the pages.  The default
  /// is 1, so every page will become a new document.  If it was two then each document would
  /// contain 2 pages.  If the source document had 5 pages it would split into
  /// 3 new documents, 2 documents containing 2 pages and 1 document containing one
  /// page.
  ///
  /// [split] The number of pages each split document should contain.
  void setSplitAtPage(int split) {
    if (split <= 0) {
      throw ArgumentError("Number of pages is smaller than one");
    }
    _splitLength = split;
  }

  /// This will set the start page.
  ///
  /// [start] the 1-based start page
  void setStartPage(int start) {
    if (start <= 0) {
      throw ArgumentError("Start page is smaller than one");
    }
    _startPage = start;
  }

  /// This will set the end page.
  ///
  /// [end] the 1-based end page
  void setEndPage(int end) {
    if (end <= 0) {
      throw ArgumentError("End page is smaller than one");
    }
    if (end < _startPage) {
      throw ArgumentError("End page is smaller than startPage");
    }
    _endPage = end;
  }

  void _processPages() {
    // TODO PDPageTree in Dart port seems to support index access and count, but not direct iteration easily if not implemented
    // But PDPageTree usually implements Iterable or has a way to get all pages.
    // Let's assume we can iterate or use index.
    // In PDDocument.dart: int get numberOfPages => documentCatalog.pages.count;
    // PDPage getPage(int pageIndex) => documentCatalog.pages[pageIndex];

    for (int i = 0; i < _sourceDocument!.numberOfPages; i++) {
      final page = _sourceDocument!.getPage(i);
      if (_currentPageNumber + 1 >= _startPage && _currentPageNumber + 1 <= _endPage) {
        _processPage(page);
        _currentPageNumber++;
      } else {
        if (_currentPageNumber > _endPage) {
          break;
        } else {
          _currentPageNumber++;
        }
      }
    }
  }

  void _createNewDocumentIfNecessary() {
    if (splitAtPage(_currentPageNumber) || _currentDestinationDocument == null) {
      _currentDestinationDocument = createNewDocument();
      _destinationDocuments!.add(_currentDestinationDocument!);
      _pageDictMap = <COSDictionary, COSDictionary>{};
      _pageDictMaps!.add(_pageDictMap!);
      _annotDictMap = <COSDictionary, COSDictionary>{};
      _annotDictMaps!.add(_annotDictMap!);
    }
  }

  /// Check if it is necessary to create a new document.
  /// By default a split occurs at every page.
  bool splitAtPage(int pageNumber) {
    return (pageNumber + 1 - max(1, _startPage)) % _splitLength == 0;
  }

  /// Create a new document to write the split contents to.
  PDDocument createNewDocument() {
    final document = PDDocument();
    document.version = _sourceDocument!.version;
    final sourceDocumentInformation = _sourceDocument!.documentInformation;
    
    // PDFBOX-5317: Image Capture Plus files where /Root and /Info share the same dictionary
    // Only copy simple elements to avoid huge files
    final sourceDocumentInformationDictionary = sourceDocumentInformation.cosObject;
    final destDocumentInformationDictionary = COSDictionary();
    
    for (final entry in sourceDocumentInformationDictionary.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is COSDictionary) {
        _logger.warning("Nested entry for key '${key.name}' skipped in document information dictionary");
        if (_sourceDocument!.documentCatalog.cosObject == _sourceDocument!.documentInformation.cosObject) {
           _logger.warning("/Root and /Info share the same dictionary");
        }
        continue;
      }
      if (COSName.type == key) {
        continue; // there is no /Type in the document information dictionary
      }
      destDocumentInformationDictionary[key] = value;
    }
    document.documentInformation = PDDocumentInformation(dictionary: destDocumentInformationDictionary);
    
    final destCatalog = document.documentCatalog;
    final sourceCatalog = _sourceDocument!.documentCatalog;
    
    destCatalog.viewerPreferences = sourceCatalog.viewerPreferences;
    destCatalog.language = sourceCatalog.language;
    destCatalog.metadata = sourceCatalog.metadata;
    
    destCatalog.markInfo = sourceCatalog.markInfo;
    
    return document;
  }

  /// Interface to start processing a new page.
  void _processPage(PDPage page) {
    _createNewDocumentIfNecessary();

    final imported = _importPage(_currentDestinationDocument!, page);
    
    if (page.resources.cosObject.isNotEmpty && !page.cosObject.containsKey(COSName.resources)) {
       imported.resources = page.resources;
       _logger.info("Resources imported in Splitter");
    }
    if (imported.cosObject.containsKey(COSName.b)) {
      imported.cosObject.removeItem(COSName.b);
      _logger.warning("/B entry (beads) removed by splitter");
    }
    
    // remove page links to avoid copying not needed resources 
    _processAnnotations(imported);

    _pageDictMap![page.cosObject] = imported.cosObject;
  }
  
  // Helper to import page since PDDocument might not have it yet
  PDPage _importPage(PDDocument destination, PDPage page) {
      final cloner = PDFCloneUtility(destination);
      final pageDict = cloner.cloneForNewDocument(page.cosObject) as COSDictionary;
      final newPage = PDPage(pageDict, destination.resourceCache);
      
      // We need to remove Parent so it can be added to the new tree
      pageDict.removeItem(COSName.parent);
      
      destination.addPage(newPage);
      return newPage;
  }

  void _processAnnotations(PDPage imported) {
    final annotations = imported.annotations;
    if (annotations.isEmpty) {
      return;
    }
    
    final clonedAnnotations = <PDAnnotation>[];
    for (final annotation in annotations) {
        // create a shallow clone
        final clonedDict = COSDictionary.fromDictionary(annotation.cosObject);
        final annotationClone = PDAnnotationFactory.instance.createAnnotation(clonedDict);
        
        if (annotationClone != null) {
            _annotDictMap![annotation.cosObject] = clonedDict;
            clonedAnnotations.add(annotationClone);
            
            // TODO: Handle PDAnnotationLink, PDAnnotationWidget, PDAnnotationMarkup, PDAnnotationPopup
            // For now we just clone them shallowly
            
            if (annotation.cosObject.containsKey(COSName.parent)) {
                 // remove non-terminal field /Parent reference
                 // annotationClone.cosObject.removeItem(COSName.parent);
            }
        }
    }
    imported.annotations = clonedAnnotations;
  }
}

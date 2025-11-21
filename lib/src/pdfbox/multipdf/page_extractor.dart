import 'dart:math';

import '../pdmodel/pd_document.dart';
import 'splitter.dart';

/// This class will extract one or more sequential pages and create a new document.
class PageExtractor {
  final PDDocument _sourceDocument;
  
  // first page to extract is page 1 (by default)
  int _startPage = 1;
  
  int _endPage;
  
  /// Creates a new instance of PageExtractor
  /// [sourceDocument] The document to split.
  /// [startPage] The first page you want extracted (1-based, inclusive)
  /// [endPage] The last page you want extracted (1-based, inclusive)
  PageExtractor(this._sourceDocument, {int startPage = 1, int? endPage})
      : _startPage = startPage,
        _endPage = endPage ?? _sourceDocument.numberOfPages;

  /// This will take a document and extract the desired pages into a new 
  /// document.  Both startPage and endPage are included in the extracted 
  /// document.  If the endPage is greater than the number of pages in the 
  /// source document, it will go to the end of the document.  If startPage is
  /// less than 1, it'll start with page 1.  If startPage is greater than 
  /// endPage or greater than the number of pages in the source document, a 
  /// blank document will be returned.
  /// 
  /// Returns The extracted document
  PDDocument extract() {
    if (_endPage - _startPage + 1 <= 0) {
      return PDDocument();
    }
    final splitter = Splitter();
    splitter.setStartPage(max(_startPage, 1));
    splitter.setEndPage(min(_endPage, _sourceDocument.numberOfPages));
    splitter.setSplitAtPage(_endPage - _startPage + 1);
    final splitted = splitter.split(_sourceDocument);
    if (splitted.isEmpty) {
        return PDDocument();
    }
    return splitted[0];
  }

  /// Gets the first page number to be extracted.
  int get startPage => _startPage;

  /// Sets the first page number to be extracted.
  set startPage(int startPage) {
    _startPage = startPage;
  }

  /// Gets the last page number (inclusive) to be extracted.
  int get endPage => _endPage;

  /// Sets the last page number to be extracted.
  set endPage(int endPage) {
    _endPage = endPage;
  }
}

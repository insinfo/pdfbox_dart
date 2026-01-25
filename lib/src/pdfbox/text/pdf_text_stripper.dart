import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:pdfbox_dart/src/utils/unorm/export.dart' as unorm;

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_tree.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/documentnavigation/outline/pd_outline_item.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/pagenavigation/pd_thread_bead.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/markedcontent/pd_marked_content.dart';
import 'package:pdfbox_dart/src/pdfbox/text/legacy_pdf_stream_engine.dart';
import 'package:pdfbox_dart/src/pdfbox/text/text_position.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';

import 'package:pdfbox_dart/src/pdfbox/text/text_position_comparator.dart';

/// This class will take a pdf document and strip out all of the text and ignore the formatting and such.
/// Please note; it is up to clients of this class to verify that a specific user has the correct permissions
/// to extract text from the PDF document.
class PDFTextStripper extends LegacyPDFStreamEngine {
  // static final Logger _log = Logger('PDFTextStripper');

  static double defaultIndentThreshold = 2.0;
  static double defaultDropThreshold = 2.5;

  // Emulating system properties via static flags for Dart
  static bool useLegacySort = false; // "org.apache.pdfbox.util.TextPositionComparator.legacy"
  static final String LINE_SEPARATOR = Platform.lineTerminator;

  String lineSeparator = LINE_SEPARATOR;
  String wordSeparator = " ";
  String paragraphStart = "";
  String paragraphEnd = "";
  String pageStart = "";
  String pageEnd = LINE_SEPARATOR;
  String articleStart = "";
  String articleEnd = "";

  int currentPageNo = 1;
  int startPage = 1;
  int endPage = 2147483647; // Integer.MAX_VALUE
  PDOutlineItem? startBookmark;

  // 1-based bookmark pages
  int startBookmarkPageNumber = -1;
  int endBookmarkPageNumber = -1;

  PDOutlineItem? endBookmark;
  bool suppressDuplicateOverlappingText = true;
  bool shouldSeparateByBeads = true;
  bool sortByPosition = false;
  bool addMoreFormatting = false;
  bool ignoreContentStreamSpaceGlyphs = false;

  double indentThreshold = defaultIndentThreshold;
  double dropThreshold = defaultDropThreshold;

  // we will need to estimate where to add spaces, these are used to help guess
  double spacingTolerance = .5;
  double averageCharTolerance = .3;

  List<PDRectangle?>? beadRectangles;

  // use a stack so we don't get confused if another BDC within "/ActualText... BDC" block
  final List<PDMarkedContent> currentMarkedContents = [];
  // to replace the unicode of the first TextPosition and empty the others
  bool firstActualTextPosition = false;
  String? actualText;

  /// The charactersByArticle is used to extract text by article divisions.
  List<List<TextPosition>> charactersByArticle = [];

  final Map<String, SplayTreeMap<double, SplayTreeSet<double>>>
      characterListMapping = {};

  static final RegExp _listItemPattern = RegExp(r"^\s*(\d+\.|[a-zA-Z]\.|[a-zA-Z]\)|•|-|–|—)\s*");

  PDDocument? document;
  StringSink? output;

  /// True if we started a paragraph but haven't ended it yet.
  bool inParagraph = false;

  PDFTextStripper() : super() {
    // Operators are added by super class (PDFStreamEngine)
    // Java adds specific MarkedContent operators here.
    // We assume they are already registered or we need to register them if they are special.
    // PDFStreamEngine in Dart registers MarkedContent operators.
  }

  /// This will return the text of a document.
  Future<String> getText(PDDocument doc) async {
    StringBuffer outputStream = StringBuffer();
    await writeText(doc, outputStream);
    return outputStream.toString();
  }

  void resetEngine() {
    currentPageNo = 1;
    document = null;
    charactersByArticle.clear();
    characterListMapping.clear();
  }

  /// This will take a PDDocument and write the text of that document to the print writer.
  Future<void> writeText(PDDocument doc, StringSink outputStream) async {
    resetEngine();
    document = doc;
    output = outputStream;
    if (addMoreFormatting) {
      paragraphEnd = lineSeparator;
      pageStart = lineSeparator;
      articleStart = lineSeparator;
      articleEnd = lineSeparator;
    }
    startDocument(doc);
    await processPages(doc.pages);
    endDocument(doc);
  }

  /// This will process all of the pages and the text that is in them.
  Future<void> processPages(PDPageTree pages) async {
    PDPage? startBookmarkPage = startBookmark == null
        ? null
        : await _findDestinationPage(startBookmark!, document!);
    if (startBookmarkPage != null) {
      startBookmarkPageNumber = pages.indexOf(startBookmarkPage) + 1;
    } else {
      startBookmarkPageNumber = -1;
    }

    PDPage? endBookmarkPage = endBookmark == null
        ? null
        : await _findDestinationPage(endBookmark!, document!);
    if (endBookmarkPage != null) {
      endBookmarkPageNumber = pages.indexOf(endBookmarkPage) + 1;
    } else {
      endBookmarkPageNumber = -1;
    }

    if (startBookmarkPageNumber == -1 &&
        startBookmark != null &&
        endBookmarkPageNumber == -1 &&
        endBookmark != null &&
        startBookmark!.cosObject == endBookmark!.cosObject) {
      startBookmarkPageNumber = 0;
      endBookmarkPageNumber = 0;
    }

    for (PDPage page in pages) {
      if (page.hasContents) {
        processPage(page);
      }
      currentPageNo++;
    }
  }

  // Helper to find destination page (placeholder)
  // Helper to find destination page
  Future<PDPage?> _findDestinationPage(
      PDOutlineItem item, PDDocument doc) async {
    final dest = item.destination;
    if (dest == null) {
      return null;
    }
    return _processDestination(dest, doc);
  }

  PDPage? _processDestination(PDDestination dest, PDDocument doc) {
    if (dest is PDNamedDestination) {
      final names = doc.documentCatalog.names;
      final destsTree = names.dests;
      if (destsTree != null) {
        final found = destsTree.getValue(dest.name);
        if (found != null) {
          return _processDestination(found, doc);
        }
      }
      // Fallback: Check if /Dests exists directly in names dictionary or catalog?
      // PDFBox Java checks NameDictionary.getDests(), if null checks Catalog.getDests().
      // PDDocumentNameDictionary.dests already does this fallback check in its getter.
      return null;
    }

    if (dest is PDPageDestination) {
      final pageNumber = dest.pageNumber;
      if (pageNumber != null) {
        if (pageNumber != -1) {
           return doc.getPage(pageNumber);
        }
      }
      
      var pageObj = dest.page;
      if (pageObj is COSObject) {
        pageObj = pageObj.object;
      }
      
      if (pageObj is COSDictionary) {
        // We have the page dictionary, we need to return a PDPage.
        // It's suboptimal that we don't know the index directly here without searching,
        // but PDFTextStripper just needs the PDPage object to match with the page tree iteration.
        // It uses equality check.
        // However, we need to ensure this PDPage refers to the same object in cache/tree.
        // Since we are iterating doc.pages, checking identical(page.cosObject, pageObj) usually works.
        // We can return a wrapper.
        return PDPage(pageObj, doc.resourceCache);
      }
    }
    return null;
  }

  void startDocument(PDDocument document) {}

  void endDocument(PDDocument document) {}

  @override
  void processPage(PDPage page) {
    if (currentPageNo >= startPage &&
        currentPageNo <= endPage &&
        (startBookmarkPageNumber == -1 ||
            currentPageNo >= startBookmarkPageNumber) &&
        (endBookmarkPageNumber == -1 ||
            currentPageNo <= endBookmarkPageNumber)) {
      startPageMethod(page);

      int numberOfArticleSections = 1;
      if (shouldSeparateByBeads) {
        fillBeadRectangles(page);
        numberOfArticleSections += (beadRectangles?.length ?? 0) * 2;
      }
      int originalSize = charactersByArticle.length;
      // charactersByArticle.ensureCapacity(numberOfArticleSections); // Dart lists grow automatically
      int lastIndex = math.max(numberOfArticleSections, originalSize);
      for (int i = 0; i < lastIndex; i++) {
        if (i < originalSize) {
          charactersByArticle[i].clear();
        } else {
          if (numberOfArticleSections < originalSize) {
            charactersByArticle.removeAt(i);
            i--; // adjust index after removal
            lastIndex--;
          } else {
            charactersByArticle.add([]);
          }
        }
      }
      characterListMapping.clear();
      super.processPage(page);
      writePage();
      endPageMethod(page);
      // Page resource cache cleanup is handled by the document resource cache.
    }
  }

  void fillBeadRectangles(PDPage page) {
    beadRectangles = [];
    for (PDThreadBead bead in page.threadBeads) {
      if (bead.rectangle == null) {
        beadRectangles!.add(null);
        continue;
      }

      PDRectangle rect = bead.rectangle!;

      // bead rectangle is in PDF coordinates (y=0 is bottom),
      // glyphs are in image coordinates (y=0 is top),
      // so we must flip
      PDRectangle mediaBox = page.mediaBox ?? PDRectangle.letter;
      double upperRightY = mediaBox.upperRightY - rect.lowerLeftY;
      double lowerLeftY = mediaBox.upperRightY - rect.upperRightY;
      rect.lowerLeftY = lowerLeftY;
      rect.upperRightY = upperRightY;

      // adjust for cropbox
      PDRectangle? cropBox = page.cropBox;
      if (cropBox != null && (cropBox.lowerLeftX != 0 || cropBox.lowerLeftY != 0)) {
        rect.lowerLeftX = rect.lowerLeftX - cropBox.lowerLeftX;
        rect.lowerLeftY = rect.lowerLeftY - cropBox.lowerLeftY;
        rect.upperRightX = rect.upperRightX - cropBox.lowerLeftX;
        rect.upperRightY = rect.upperRightY - cropBox.lowerLeftY;
      }

      beadRectangles!.add(rect);
    }
  }

  void startArticle({bool isLTR = true}) {
    output!.write(articleStart);
  }

  void endArticle() {
    output!.write(articleEnd);
  }

  void startPageMethod(PDPage page) {
    // default is to do nothing
  }

  void endPageMethod(PDPage page) {
    // default is to do nothing
  }

  static const double END_OF_LAST_TEXT_X_RESET_VALUE = -1;
  static const double MAX_Y_FOR_LINE_RESET_VALUE = -double.maxFinite;
  static const double EXPECTED_START_OF_NEXT_WORD_X_RESET_VALUE =
      -double.maxFinite;
  static const double MAX_HEIGHT_FOR_LINE_RESET_VALUE = -1;
  static const double MIN_Y_TOP_FOR_LINE_RESET_VALUE = double.maxFinite;
  static const double LAST_WORD_SPACING_RESET_VALUE = -1;

  void writePage() {
    double maxYForLine = MAX_Y_FOR_LINE_RESET_VALUE;
    double minYTopForLine = MIN_Y_TOP_FOR_LINE_RESET_VALUE;
    double endOfLastTextX = END_OF_LAST_TEXT_X_RESET_VALUE;
    double lastWordSpacing = LAST_WORD_SPACING_RESET_VALUE;
    double maxHeightForLine = MAX_HEIGHT_FOR_LINE_RESET_VALUE;
    PositionWrapper? lastPosition;
    PositionWrapper? lastLineStartPosition;

    bool startOfPage = true;
    bool startOfArticle;
    if (charactersByArticle.isNotEmpty) {
      writePageStart();
    }

    for (List<TextPosition> textList in charactersByArticle) {
      if (sortByPosition) {
        TextPositionComparator comparator = TextPositionComparator();
        textList.sort(comparator.compare);
        removeContainedSpaces(textList);
      }

      startArticle();
      startOfArticle = true;

      List<LineItem> line = [];

      Iterator<TextPosition> textIter = textList.iterator;

      double previousAveCharWidth = -1;
      while (textIter.moveNext()) {
        TextPosition position = textIter.current;
        PositionWrapper current = PositionWrapper(position);
        String characterValue = position.getUnicode();

        if (" " == characterValue && ignoreContentStreamSpaceGlyphs) {
          continue;
        }

        if (lastPosition != null &&
            hasFontOrSizeChanged(position, lastPosition.getTextPosition())) {
          previousAveCharWidth = -1;
        }
        double positionX;
        double positionY;
        double positionWidth;
        double positionHeight;

        if (sortByPosition) {
          positionX = position.getXDirAdj();
          positionY = position.getYDirAdj();
          positionWidth = position.getWidthDirAdj();
          positionHeight = position.getHeightDir();
        } else {
          positionX = position.getX();
          positionY = position.getY();
          positionWidth = position.getWidth();
          positionHeight = position.getHeight();
        }

        int wordCharCount = position.getIndividualWidths().length;

        double wordSpacing = position.getWidthOfSpace();
        double deltaSpace;
        if (wordSpacing == 0 || wordSpacing.isNaN) {
          deltaSpace = double.maxFinite;
        } else {
          if (lastWordSpacing < 0) {
            deltaSpace = wordSpacing * spacingTolerance;
          } else {
            deltaSpace =
                (wordSpacing + lastWordSpacing) / 2.0 * spacingTolerance;
          }
        }

        double averageCharWidth;
        if (previousAveCharWidth < 0) {
          averageCharWidth = positionWidth / wordCharCount;
        } else {
          averageCharWidth =
              (previousAveCharWidth + positionWidth / wordCharCount) / 2.0;
        }
        double deltaCharWidth = averageCharWidth * averageCharTolerance;

        double expectedStartOfNextWordX =
            EXPECTED_START_OF_NEXT_WORD_X_RESET_VALUE;
        if (endOfLastTextX != END_OF_LAST_TEXT_X_RESET_VALUE) {
          expectedStartOfNextWordX =
              endOfLastTextX + math.min(deltaSpace, deltaCharWidth);
        }

        if (lastPosition != null) {
          if (startOfArticle) {
            lastPosition.setArticleStart();
            startOfArticle = false;
          }

          if (!overlap(
              positionY, positionHeight, maxYForLine, maxHeightForLine)) {
            writeLine(normalize(line));
            line.clear();
            lastLineStartPosition = handleLineSeparation(current, lastPosition,
                lastLineStartPosition, maxHeightForLine);
            expectedStartOfNextWordX =
                EXPECTED_START_OF_NEXT_WORD_X_RESET_VALUE;
            maxYForLine = MAX_Y_FOR_LINE_RESET_VALUE;
            maxHeightForLine = MAX_HEIGHT_FOR_LINE_RESET_VALUE;
            minYTopForLine = MIN_Y_TOP_FOR_LINE_RESET_VALUE;
          }

          if (expectedStartOfNextWordX !=
                  EXPECTED_START_OF_NEXT_WORD_X_RESET_VALUE &&
              expectedStartOfNextWordX < positionX &&
              (wordSeparator.isEmpty ||
                  (lastPosition.getTextPosition().getUnicode().isNotEmpty &&
                      !lastPosition
                          .getTextPosition()
                          .getUnicode()
                          .endsWith(wordSeparator)))) {
            line.add(LineItem.getWordSeparator());
          }

          if ((position.getX() - lastPosition.getTextPosition().getX()).abs() >
              (wordSpacing + deltaSpace)) {
            maxYForLine = MAX_Y_FOR_LINE_RESET_VALUE;
            maxHeightForLine = MAX_HEIGHT_FOR_LINE_RESET_VALUE;
            minYTopForLine = MIN_Y_TOP_FOR_LINE_RESET_VALUE;
          }
        }
        if (positionY >= maxYForLine) {
          maxYForLine = positionY;
        }
        endOfLastTextX = positionX + positionWidth;

        if (characterValue.isNotEmpty) {
          if (startOfPage && lastPosition == null) {
            writeParagraphStart();
          }
          line.add(LineItem(position));
        }
        maxHeightForLine = math.max(maxHeightForLine, positionHeight);
        minYTopForLine = math.min(minYTopForLine, positionY - positionHeight);
        lastPosition = current;
        if (startOfPage) {
          lastPosition.setParagraphStart();
          lastPosition.setLineStart();
          lastLineStartPosition = lastPosition;
          startOfPage = false;
        }
        lastWordSpacing = wordSpacing;
        previousAveCharWidth = averageCharWidth;
      }

      if (line.isNotEmpty) {
        writeLine(normalize(line));
        writeParagraphEnd();
      }
      endArticle();
    }
    writePageEnd();
  }

  bool hasFontOrSizeChanged(TextPosition current, TextPosition last) {
    if (current.getFontSize() != last.getFontSize()) {
      return true;
    }
    if (current.getFont() == last.getFont()) {
      return false;
    }
    String? currentFontName = current.getFont()?.name;
    String? lastFontName = last.getFont()?.name;
    if (currentFontName != null) {
      return currentFontName != lastFontName;
    }
    if (lastFontName != null) {
      return true;
    }
    return current.getFont().hashCode != last.getFont().hashCode;
  }

  bool overlap(double y1, double height1, double y2, double height2) {
    return within(y1, y2, .1) ||
        y2 <= y1 && y2 >= y1 - height1 ||
        y1 <= y2 && y1 >= y2 - height2;
  }

  void removeContainedSpaces(List<TextPosition> textList) {
    if (textList.isEmpty) return;

    final toRemove = <TextPosition>{};
    final size = textList.length;

    // Use a simplified O(N^2) check. Since N is usually page size, it should be acceptable.
    // Optimization: if strictly sorted by Y, we could limit search range, 
    // but textList might be large.
    // PDFBox implementation iterates through all.
    
    for (int i = 0; i < size; i++) {
        final position = textList[i];
        if (position.getUnicode() == " ") {
            // Check if this space is contained in another character
            final x = position.getXDirAdj();
            final y = position.getYDirAdj();
            final w = position.getWidthDirAdj();
            final h = position.getHeightDir();
            
            // Assume containment means fully contained or mostly contained?
            // "Contained" usually means the space bbox is inside another char's bbox.
            // But we should tolerate small rounding errors?
            
            bool isContained = false;
            for (int k = 0; k < size; k++) {
                if (i == k) continue;
                final other = textList[k];
                if (toRemove.contains(other)) continue;

                final ox = other.getXDirAdj();
                final oy = other.getYDirAdj();
                final ow = other.getWidthDirAdj();
                final oh = other.getHeightDir();

                // Check containment:
                // other.x <= space.x && other.x + width >= space.x + width
                // other.y <= space.y && other.y + height >= space.y + height (roughly)
                // Note: Text Y coordinates behavior depends on coordinate system (bottom-up vs top-down).
                // PDFTextStripper usually deals with normalized Y (top-down or similar logic).
                // TextPositionComparator uses adjusted Y.
                
                // Let's check X containment first which is most common (kerning/ligatures)
                if (ox <= x && (ox + ow) >= (x + w)) {
                    // Check Y overlap
                    if (overlap(y, h, oy, oh)) {
                        isContained = true;
                        break;
                    }
                }
            }
            if (isContained) {
                toRemove.add(position);
            }
        }
    }
    if (toRemove.isNotEmpty) {
        textList.removeWhere((t) => toRemove.contains(t));
    }
  }

  void writeLineSeparator() {
    output!.write(lineSeparator);
  }

  void writeWordSeparator() {
    output!.write(wordSeparator);
  }

  void writeCharacters(TextPosition text) {
    output!.write(text.getUnicode());
  }

  void writeString(String text, [List<TextPosition>? textPositions]) {
    output!.write(text);
  }

  bool within(double first, double second, double variance) {
    return second < first + variance && second > first - variance;
  }

  @override
  void beginMarkedContentSequence(COSName tag, COSDictionary? properties) {
    PDMarkedContent markedContent = PDMarkedContent.create(tag, properties);
    currentMarkedContents.add(markedContent);
    actualText = markedContent.actualText;
    if (actualText != null) {
      actualText = actualText!.replaceAll("\u00ad", "");
      firstActualTextPosition = true;
    }
    super.beginMarkedContentSequence(tag, properties);
  }

  @override
  void endMarkedContentSequence() {
    if (currentMarkedContents.isNotEmpty) {
      PDMarkedContent markedContent = currentMarkedContents.last;
      if (markedContent.actualText != null) {
        actualText = null;
      }
      currentMarkedContents.removeLast();
    }
    super.endMarkedContentSequence();
  }

  @override
  void processTextPosition(TextPosition text) {
    if (actualText != null) {
      if (firstActualTextPosition) {
        text.unicode = actualText!;
        firstActualTextPosition = false;
      } else {
        text.unicode = "";
      }
    }
    bool showCharacter = true;
    if (suppressDuplicateOverlappingText && actualText == null) {
      showCharacter = false;
      String textCharacter = text.getUnicode();
      double textX = text.getX();
      double textY = text.getY();

      SplayTreeMap<double, SplayTreeSet<double>> sameTextCharacters =
          characterListMapping.putIfAbsent(
              textCharacter,
              () => SplayTreeMap<double, SplayTreeSet<double>>(
                  (a, b) => a.compareTo(b)));

      bool suppressCharacter = false;
      double tolerance = text.getWidth() / textCharacter.length / 3.0;

      // Use ordered traversal to limit candidate checks to the tolerance range.
      if (sameTextCharacters.isNotEmpty) {
          final firstKey = sameTextCharacters.firstKey();
          final lastKey = sameTextCharacters.lastKey();
          
          if (firstKey != null && lastKey != null) {
              final minX = textX - tolerance;
              final maxX = textX + tolerance;
              
              if (maxX >= firstKey && minX <= lastKey) {
                  // Only iterate if overlap is possible
                   for (double x in sameTextCharacters.keys) {
                    if (x < minX) continue;
                    if (x > maxX) break; // Sorted keys, so we can stop
                    
                    SplayTreeSet<double> yMatches = sameTextCharacters[x]!;
                    final minY = textY - tolerance;
                    final maxY = textY + tolerance;
                    
                    // Same for Y
                    if (yMatches.isNotEmpty) {
                        if (yMatches.first > maxY || yMatches.last < minY) continue;
                        
                        for (double y in yMatches) {
                            if (y >= minY && y <= maxY) {
                                suppressCharacter = true;
                                break;
                            }
                        }
                    }
                    if (suppressCharacter) break;
                  }
              }
          }
      }

      if (!suppressCharacter) {
        SplayTreeSet<double> ySet = sameTextCharacters.putIfAbsent(
            textX, () => SplayTreeSet<double>((a, b) => a.compareTo(b)));
        ySet.add(textY);
        showCharacter = true;
      }
    }

    if (showCharacter) {
      int foundArticleDivisionIndex = -1;
      int notFoundButFirstLeftAndAboveArticleDivisionIndex = -1;
      int notFoundButFirstLeftArticleDivisionIndex = -1;
      int notFoundButFirstAboveArticleDivisionIndex = -1;
      double x = text.getX();
      double y = text.getY();

      if (shouldSeparateByBeads && beadRectangles != null) {
        for (int i = 0;
            i < beadRectangles!.length && foundArticleDivisionIndex == -1;
            i++) {
          PDRectangle? rect = beadRectangles![i];
          if (rect != null) {
            if (rect.contains(x, y)) {
              foundArticleDivisionIndex = i * 2 + 1;
            } else if ((x < rect.lowerLeftX || y < rect.upperRightY) &&
                notFoundButFirstLeftAndAboveArticleDivisionIndex == -1) {
              notFoundButFirstLeftAndAboveArticleDivisionIndex = i * 2;
            } else if (x < rect.lowerLeftX &&
                notFoundButFirstLeftArticleDivisionIndex == -1) {
              notFoundButFirstLeftArticleDivisionIndex = i * 2;
            } else if (y < rect.upperRightY &&
                notFoundButFirstAboveArticleDivisionIndex == -1) {
              notFoundButFirstAboveArticleDivisionIndex = i * 2;
            }
          } else {
            foundArticleDivisionIndex = 0;
          }
        }
      } else {
        foundArticleDivisionIndex = 0;
      }

      int articleDivisionIndex;
      if (foundArticleDivisionIndex != -1) {
        articleDivisionIndex = foundArticleDivisionIndex;
      } else if (notFoundButFirstLeftAndAboveArticleDivisionIndex != -1) {
        articleDivisionIndex = notFoundButFirstLeftAndAboveArticleDivisionIndex;
      } else if (notFoundButFirstLeftArticleDivisionIndex != -1) {
        articleDivisionIndex = notFoundButFirstLeftArticleDivisionIndex;
      } else if (notFoundButFirstAboveArticleDivisionIndex != -1) {
        articleDivisionIndex = notFoundButFirstAboveArticleDivisionIndex;
      } else {
        articleDivisionIndex = charactersByArticle.length - 1;
      }

      if (articleDivisionIndex >= charactersByArticle.length) {
        // Should not happen if logic is correct, but ensure safety
        if (charactersByArticle.isEmpty) charactersByArticle.add([]);
        articleDivisionIndex = charactersByArticle.length - 1;
      }

      List<TextPosition> textList = charactersByArticle[articleDivisionIndex];

      if (textList.isEmpty) {
        textList.add(text);
      } else {
        TextPosition previousTextPosition = textList.last;
        if (text.isDiacritic() && previousTextPosition.contains(text)) {
          previousTextPosition.mergeDiacritic(text);
        } else if (previousTextPosition.isDiacritic() &&
            text.contains(previousTextPosition)) {
          text.mergeDiacritic(previousTextPosition);
          textList.removeLast();
          textList.add(text);
        } else {
          textList.add(text);
        }
      }
    }
  }

  void writeParagraphSeparator() {
    writeParagraphEnd();
    writeParagraphStart();
  }

  void writeParagraphStart() {
    if (inParagraph) {
      writeParagraphEnd();
      inParagraph = false;
    }
    output!.write(paragraphStart);
    inParagraph = true;
  }

  void writeParagraphEnd() {
    if (!inParagraph) {
      writeParagraphStart();
    }
    output!.write(paragraphEnd);
    inParagraph = false;
  }

  void writePageStart() {
    output!.write(pageStart);
  }

  void writePageEnd() {
    output!.write(pageEnd);
  }

  PositionWrapper handleLineSeparation(
      PositionWrapper current,
      PositionWrapper lastPosition,
      PositionWrapper? lastLineStartPosition,
      double maxHeightForLine) {
    current.setLineStart();
    isParagraphSeparation(
        current, lastPosition, lastLineStartPosition, maxHeightForLine);
    lastLineStartPosition = current;
    if (current.isParagraphStart) {
      if (lastPosition.isArticleStart) {
        if (lastPosition.isLineStart) {
          writeLineSeparator();
        }
        writeParagraphStart();
      } else {
        writeLineSeparator();
        writeParagraphSeparator();
      }
    } else {
      writeLineSeparator();
    }
    return lastLineStartPosition;
  }

  void isParagraphSeparation(
      PositionWrapper position,
      PositionWrapper lastPosition,
      PositionWrapper? lastLineStartPosition,
      double maxHeightForLine) {
    bool result = false;
    if (lastLineStartPosition == null) {
      result = true;
    } else {
      double yGap = (position.getTextPosition().getYDirAdj() -
              lastPosition.getTextPosition().getYDirAdj())
          .abs();
      double newYVal = _multiplyFloat(dropThreshold, maxHeightForLine);
      double xGap = position.getTextPosition().getXDirAdj() -
          lastLineStartPosition.getTextPosition().getXDirAdj();
      double newXVal = _multiplyFloat(
          indentThreshold, position.getTextPosition().getWidthOfSpace());
      double positionWidth =
          _multiplyFloat(0.25, position.getTextPosition().getWidth());

      if (yGap > newYVal) {
        result = true;
      } else if (xGap > newXVal) {
        if (!lastLineStartPosition.isParagraphStart) {
          result = true;
        } else {
          position.setHangingIndent();
        }
      } else if (xGap < -position.getTextPosition().getWidthOfSpace()) {
        if (!lastLineStartPosition.isParagraphStart) {
          result = true;
        }
      } else if (xGap.abs() < positionWidth) {
        if (lastLineStartPosition.isHangingIndent) {
          position.setHangingIndent();
        } else if (lastLineStartPosition.isParagraphStart) {
          // List item pattern matching
          // Check if the current line looks like a list item (e.g. "1.", "a)", "•", "-")
          final match = _listItemPattern.firstMatch(position.getTextPosition().getUnicode());
          if (match != null) {
              // It's a list item, so it should probably be separate from the paragraph start?
              // PDFBox logic: if it IS a pattern, we might want to treat it as paragraph start (which it is, since result=true happens if we fall through?)
              // Actually PDFBox sets result=true in some cases.
              // Here we are inside `xGap.abs() < positionWidth`.
              // Meaning they are aligned vertically (same indentation).
              // If indentation is same, and new line looks like a list item, 
              // it means we might have:
              //   Paragraph text...
              //   1. List item...
              // If xGap is small (aligned), it's likely a continuation of the paragraph 
              // UNLESS it's a new list item.
              result = true;
          }
        }
      }
    }
    if (result) {
      position.setParagraphStart();
    }
  }

  double _multiplyFloat(double value1, double value2) {
    return (value1 * value2 * 1000).round() / 1000.0;
  }

  void writeLine(List<WordWithTextPositions> line) {
    int numberOfStrings = line.length;
    for (int i = 0; i < numberOfStrings; i++) {
      WordWithTextPositions word = line[i];
      writeString(word.getText(), word.getTextPositions());
      if (i < numberOfStrings - 1) {
        writeWordSeparator();
      }
    }
  }

  List<WordWithTextPositions> normalize(List<LineItem> line) {
    List<WordWithTextPositions> normalized = [];
    StringBuffer lineBuilder = StringBuffer();
    List<TextPosition> wordPositions = [];

    for (LineItem item in line) {
      _normalizeAdd(normalized, lineBuilder, wordPositions, item);
    }

    if (lineBuilder.length > 0) {
      normalized.add(createWord(lineBuilder.toString(), wordPositions));
    }
    return normalized;
  }

  void _normalizeAdd(
      List<WordWithTextPositions> normalized,
      StringBuffer lineBuilder,
      List<TextPosition> wordPositions,
      LineItem item) {
    if (item.isWordSeparator()) {
      normalized.add(createWord(
          lineBuilder.toString(), List<TextPosition>.from(wordPositions)));
      lineBuilder.clear();
      wordPositions.clear();
    } else {
      TextPosition text = item.getTextPosition()!;
      lineBuilder.write(text.getVisuallyOrderedUnicode());
      wordPositions.add(text);
    }
  }

  WordWithTextPositions createWord(
      String word, List<TextPosition> wordPositions) {
    return WordWithTextPositions(normalizeWord(word), wordPositions);
  }

  String normalizeWord(String word) {
    // Normalize word
    String normalized = unorm.nfkc(word);
    
    // PDFBox sometimes does manual decomposition checks or specific replacements,
    // but NFKC is the standard.
    // Also handling of presentation forms.
    
    return normalized;
  }
  

}

class LineItem {
  static final LineItem WORD_SEPARATOR = LineItem();

  static LineItem getWordSeparator() {
    return WORD_SEPARATOR;
  }

  final TextPosition? textPosition;

  LineItem([this.textPosition]);

  TextPosition? getTextPosition() {
    return textPosition;
  }

  bool isWordSeparator() {
    return textPosition == null;
  }
}

class WordWithTextPositions {
  final String text;
  final List<TextPosition> textPositions;

  WordWithTextPositions(this.text, this.textPositions);

  String getText() {
    return text;
  }

  List<TextPosition> getTextPositions() {
    return textPositions;
  }
}

class PositionWrapper {
  bool isLineStart = false;
  bool isParagraphStart = false;
  bool isPageBreak = false;
  bool isHangingIndent = false;
  bool isArticleStart = false;

  TextPosition position;

  PositionWrapper(this.position);

  TextPosition getTextPosition() {
    return position;
  }

  void setLineStart() {
    isLineStart = true;
  }

  bool isLineStartMethod() => isLineStart;

  void setParagraphStart() {
    isParagraphStart = true;
  }

  bool isParagraphStartMethod() => isParagraphStart;

  void setArticleStart() {
    isArticleStart = true;
  }

  bool isArticleStartMethod() => isArticleStart;

  void setPageBreak() {
    isPageBreak = true;
  }

  bool isPageBreakMethod() => isPageBreak;

  void setHangingIndent() {
    isHangingIndent = true;
  }

  bool isHangingIndentMethod() => isHangingIndent;
}


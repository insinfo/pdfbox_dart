import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/pdfbox/contentstream/pdf_stream_engine.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_cid_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_cid_font_type2.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_simple_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_true_type_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type0_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pdfont.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/state/pd_graphics_state.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/text/text_position.dart';
import 'package:pdfbox_dart/src/pdfbox/util/matrix.dart';
import 'package:pdfbox_dart/src/pdfbox/util/vector.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/util/bounding_box.dart';

/// LEGACY text calculations which are known to be incorrect but are depended on by PDFTextStripper.
///
/// This class exists only so that we don't break the code of users who have their own subclasses of
/// PDFTextStripper. It replaces the mostly empty implementation of showGlyph() in PDFStreamEngine
/// with a heuristic implementation which is backwards compatible.
///
/// DO NOT USE THIS CODE UNLESS YOU ARE WORKING WITH PDFTextStripper.
/// THIS CODE IS DELIBERATELY INCORRECT, USE PDFStreamEngine INSTEAD.
class LegacyPDFStreamEngine extends PDFStreamEngine {
  static final Logger _log = Logger('LegacyPDFStreamEngine');

  int _pageRotation = 0;
  PDRectangle? _pageSize;
  Matrix? _translateMatrix;
  final Map<COSDictionary, double> _fontHeightMap = {};

  LegacyPDFStreamEngine() : super();

  /// This will initialize and process the contents of the stream.
  @override
  void processPage(PDPage page) {
    _pageRotation = page.rotation;
    _pageSize = page.cropBox;

    if (_pageSize!.lowerLeftX == 0 && _pageSize!.lowerLeftY == 0) {
      _translateMatrix = null;
    } else {
      // translation matrix for cropbox
      _translateMatrix = Matrix.getTranslateInstance(
          -_pageSize!.lowerLeftX, -_pageSize!.lowerLeftY);
    }
    super.processPage(page);
  }

  @override
  void showTextString(COSString text) {
    final font = currentGraphicsState!.textState.font;
    if (font == null) {
      _log.warning('No font for showTextString');
      return;
    }

    final buffer = RandomAccessReadBuffer.fromBytes(text.bytes);
    try {
      while (!buffer.isClosed && !buffer.isEOF) {
        int code = _readCode(font, buffer);
        if (code == -1) break; // EOF
        double width = font.getWidthFromFont(code);

        // Vertical text logic
        double height = 0; 
        bool isVertical = false;
        if (font is PDType0Font && font.isVertical) {
             isVertical = true;
             height = width;
             width = 0;
        }

        // Use FontMatrix for scaling instead of hardcoded / 1000
        double scalingX = font.fontMatrix.scaleX;
        double scalingY = font.fontMatrix.scaleY;
        
        Vector displacement;
        if (isVertical) {
            displacement = Vector(0, height * scalingY);
        } else {
            displacement = Vector(width * scalingX, 0);
        }

        _showGlyph(currentGraphicsState!.textMatrix!.clone(), font, code,
            displacement);

        double fontSize = currentGraphicsState!.textState.fontSize;
        double horizontalScaling =
            currentGraphicsState!.textState.horizontalScaling / 100.0;
        double charSpacing = currentGraphicsState!.textState.characterSpacing;
        double wordSpacing = 0;
        if (code == 32) {
          wordSpacing = currentGraphicsState!.textState.wordSpacing;
        }

        double tx = 0, ty = 0;
        if (isVertical) {
             ty = ((height * scalingY) * fontSize + charSpacing + wordSpacing) * horizontalScaling;
        } else {
             tx = ((width * scalingX) * fontSize + charSpacing + wordSpacing) * horizontalScaling;
        }

        Matrix translation = Matrix.getTranslateInstance(tx, ty);
        currentGraphicsState!.textMatrix =
            translation.multiply(currentGraphicsState!.textMatrix!);
      }
    } finally {
      buffer.close();
    }
  }

  int _readCode(PDFont font, RandomAccessReadBuffer buffer) {
    if (font is PDType0Font) {
      return font.readCode(buffer);
    }
    return buffer.read();
  }

  /// Called when a glyph is to be processed. The heuristic calculations here were originally
  /// written by Ben Litchfield for PDFStreamEngine.
  void _showGlyph(
      Matrix textRenderingMatrix, PDFont font, int code, Vector displacement) {
    //
    // legacy calculations which were previously in PDFStreamEngine
    //
    //  DO NOT USE THIS CODE UNLESS YOU ARE WORKING WITH PDFTextStripper.
    //  THIS CODE IS DELIBERATELY INCORRECT
    //

    PDGraphicsState state = currentGraphicsState!;
    Matrix ctm = state.currentTransformationMatrix;
    double fontSize = state.textState.fontSize;
    double horizontalScaling = state.textState.horizontalScaling / 100.0;
    Matrix textMatrix = state.textMatrix!;

    double displacementX = displacement.x;
    // the sorting algorithm is based on the width of the character. As the displacement
    // for vertical characters doesn't provide any suitable value for it, we have to
    // calculate our own
    bool isVertical = false;
    if (font is PDType0Font && font.isVertical) {
      isVertical = true;
    }

    if (isVertical) {
      displacementX = font.getWidthFromFont(code) * font.fontMatrix.scaleX;
      // there may be an additional scaling factor for true type fonts
      TrueTypeFont? ttf;
      if (font is PDTrueTypeFont) {
        ttf = font.trueTypeFont;
      } else if (font is PDType0Font) {
        PDCIDFont? cidFont = font.cidFont;
        if (cidFont is PDCIDFontType2) {
          ttf = cidFont.trueTypeFont;
        }
      }
      if (ttf != null && ttf.unitsPerEm != 1000) {
        displacementX *= 1000.0 / ttf.unitsPerEm;
      }
    }

    //
    // legacy calculations which were previously in PDFStreamEngine
    //
    //  DO NOT USE THIS CODE UNLESS YOU ARE WORKING WITH PDFTextStripper.
    //  THIS CODE IS DELIBERATELY INCORRECT
    //

    // (modified) combined displacement, this is calculated *without* taking the character
    // spacing and word spacing into account, due to legacy code in TextStripper
    double tx = displacementX * fontSize * horizontalScaling;
    double ty = displacement.y * fontSize;

    // (modified) combined displacement matrix
    Matrix td = Matrix.getTranslateInstance(tx, ty);

    // (modified) text rendering matrix
    Matrix nextTextRenderingMatrix =
        td.multiply(textMatrix).multiply(ctm); // text space -> device space
    double nextX = nextTextRenderingMatrix.translateX;
    double nextY = nextTextRenderingMatrix.translateY;

    // (modified) width and height calculations
    double dxDisplay = nextX - textRenderingMatrix.multiply(ctm).translateX;
    double? fontHeight = _fontHeightMap[font.cosObject];
    if (fontHeight == null) {
      fontHeight = computeFontHeight(font);
      _fontHeightMap[font.cosObject] = fontHeight;
    }
    double dyDisplay = fontHeight * textRenderingMatrix.multiply(ctm).scalingFactorY;

    //
    // start of the original method
    //

    // Note on variable names. There are three different units being used in this code.
    // Character sizes are given in glyph units, text locations are initially given in text
    // units, and we want to save the data in display units. The variable names should end with
    // Text or Disp to represent if the values are in text or disp units (no glyph units are
    // saved).

    double glyphSpaceToTextSpaceFactor = font.fontMatrix.scaleX;

    double spaceWidthText = 0;
    try {
      // to avoid crash as described in PDFBOX-614, see what the space displacement should be
      spaceWidthText = font.getSpaceWidth() * glyphSpaceToTextSpaceFactor;
    } catch (exception) {
      _log.warning(exception);
    }

    if (spaceWidthText == 0) {
      spaceWidthText = font.getAverageFontWidth() * glyphSpaceToTextSpaceFactor;
      // the average space width appears to be higher than necessary so make it smaller
      spaceWidthText *= .80;
    }
    if (spaceWidthText == 0) {
      spaceWidthText = 1.0; // if could not find font, use a generic value
    }

    // the space width has to be transformed into display units
    double spaceWidthDisplay =
        spaceWidthText * textRenderingMatrix.multiply(ctm).scalingFactorX;

    // use our additional glyph list for Unicode mapping
    String? unicode = font.toUnicode(code);
    // PDFont.toUnicode in Dart uses its own glyph list or encoding.
    // We might need to enhance it to use the additional glyph list if we loaded it.

    // when there is no Unicode mapping available, Acrobat simply coerces the character code
    // into Unicode, so we do the same. Subclasses of PDFStreamEngine don't necessarily want
    // this, which is why we leave it until this point in PDFTextStreamEngine.
    if (unicode == null) {
      if (font is PDSimpleFont) {
        // char c = (char) code;
        // unicode = String.valueOf(c);
        unicode = String.fromCharCode(code);
      } else {
        // Acrobat doesn't seem to coerce composite font's character codes, instead it
        // skips them. See the "allah2.pdf" TestTextStripper file.
        return;
      }
    }

    // adjust for cropbox if needed
    Matrix translatedTextRenderingMatrix;
    if (_translateMatrix == null) {
      translatedTextRenderingMatrix = textRenderingMatrix.multiply(ctm);
    } else {
      translatedTextRenderingMatrix =
          _translateMatrix!.multiply(textRenderingMatrix).multiply(ctm);
      nextX -= _pageSize!.lowerLeftX;
      nextY -= _pageSize!.lowerLeftY;
    }

    processTextPosition(TextPosition(
      pageRotation: _pageRotation,
      pageWidth: _pageSize!.width,
      pageHeight: _pageSize!.height,
      textMatrix: translatedTextRenderingMatrix,
      endX: nextX,
      endY: nextY,
      maxHeight: dyDisplay.abs(),
      individualWidth: dxDisplay,
      spaceWidth: spaceWidthDisplay.abs(),
      unicode: unicode,
      charCodes: [code],
      font: font,
      fontSize: fontSize,
      fontSizePt: (fontSize * textMatrix.multiply(ctm).scalingFactorX).toInt(),
    ));
  }

  /// Compute the font height. Override this if you want to use own calculations.
  double computeFontHeight(PDFont font) {
    BoundingBox? bbox;
    if (font is PDType0Font) {
      bbox = font.fontBoundingBox;
    } else {
      final descriptor = font.fontDescriptor;
      if (descriptor != null) {
        final bboxList = descriptor.fontBBox;
        if (bboxList != null && bboxList.length == 4) {
          bbox = BoundingBox.fromValues(bboxList[0], bboxList[1], bboxList[2], bboxList[3]);
        }
      }
    }

    if (bbox == null) {
      final metrics = font.standard14Metrics;
      if (metrics != null) {
        bbox = metrics.getFontBBox();
      }
    }

    if (bbox != null) {
      return bbox.height / 1000;
    }

    return 1.0; // Default fallback
  }

  /// A method provided as an event interface to allow a subclass to perform some specific
  /// functionality when text needs to be processed.
  void processTextPosition(TextPosition text) {
    // subclasses can override to provide specific functionality
  }

}

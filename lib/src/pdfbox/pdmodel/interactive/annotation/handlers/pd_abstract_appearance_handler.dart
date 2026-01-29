import 'dart:math';

import '../../../../cos/cos_stream.dart';
import '../../../pd_document.dart';
import '../../../pd_resources.dart';
import '../../../common/pd_rectangle.dart';
import '../../../font/pdfont.dart';
import '../../../font/pd_type1_font.dart';
import '../../../graphics/color/pd_color.dart';
import '../../../graphics/color/pd_device_gray.dart';
import '../../../graphics/color/pd_device_rgb.dart';
import '../../../graphics/color/pd_device_cmyk.dart';
import '../../../graphics/state/pd_extended_graphics_state.dart';
import '../pd_annotation.dart';
import '../pd_annotation_line.dart';
import '../pd_annotation_appearance.dart';
import '../pd_appearance_stream.dart';
import '../../../pd_appearance_content_stream.dart';
import '../pd_annotation_square_circle.dart';
import '../../../../util/matrix.dart';
import 'pd_appearance_handler.dart';

/// Generic handler to generate the fields appearance.
/// Individual handler will provide specific implementations for different field types.
abstract class PDAbstractAppearanceHandler implements PDAppearanceHandler {
  PDAbstractAppearanceHandler(this.annotation, [this.document]);

  final PDAnnotation annotation;
  final PDDocument? document;
  PDFont? _defaultFont;

  /// Line ending styles where the line has to be drawn shorter (minus line width).
  static const Set<String> shortStyles = <String>{
    PDAnnotationLine.leOpenArrow,
    PDAnnotationLine.leClosedArrow,
    PDAnnotationLine.leSquare,
    PDAnnotationLine.leCircle,
    PDAnnotationLine.leDiamond,
  };

  static const double arrowAngle = 30 * pi / 180; // 30 degrees in radians

  /// Line ending styles where there is an interior color.
  static const Set<String> interiorColorStyles = <String>{
    PDAnnotationLine.leClosedArrow,
    PDAnnotationLine.leCircle,
    PDAnnotationLine.leDiamond,
    PDAnnotationLine.leRClosedArrow,
    PDAnnotationLine.leSquare,
  };

  /// Line ending styles where the shape changes its angle, e.g. arrows.
  static const Set<String> angledStyles = <String>{
    PDAnnotationLine.leClosedArrow,
    PDAnnotationLine.leOpenArrow,
    PDAnnotationLine.leRClosedArrow,
    PDAnnotationLine.leROpenArrow,
    PDAnnotationLine.leButt,
    PDAnnotationLine.leSlash,
  };

  PDFont getDefaultFont() {
    return _defaultFont ??= PDType1Font.helvetica();
  }

  PDAnnotation getAnnotation() {
    return annotation;
  }

  PDColor? getColor() {
    final components = annotation.color;
    if (components == null) {
      return null;
    }
    switch (components.length) {
      case 1:
        return PDColor(components, PDDeviceGray.instance);
      case 3:
        return PDColor(components, PDDeviceRGB.instance);
      case 4:
        return PDColor(components, PDDeviceCMYK.instance);
      default:
        if (components.length > 4) {
           return PDColor(components.take(4).toList(), PDDeviceCMYK.instance);
        }
        return PDColor(components, PDDeviceRGB.instance);
    }
  }

  PDRectangle? getRectangle() {
    return annotation.rectangle;
  }

  COSStream createCOSStream() {
    return COSStream();
  }

  /// Get the annotations appearance dictionary.
  PDAppearanceDictionary getAppearance() {
    var appearanceDictionary = annotation.appearance;
    if (appearanceDictionary == null) {
      appearanceDictionary = PDAppearanceDictionary();
      annotation.appearance = appearanceDictionary;
    }
    return appearanceDictionary;
  }

  /// Get the annotations normal appearance content stream.
  PDAppearanceContentStream getNormalAppearanceAsContentStream(
      [bool compress = false]) {
    final appearanceEntry = getNormalAppearance();
    return getAppearanceEntryAsContentStream(appearanceEntry, compress);
  }

  /// Get the annotations down appearance.
  PDAppearanceEntry getDownAppearance() {
    final appearanceDictionary = getAppearance();
    var downAppearanceEntry = appearanceDictionary.downAppearance;

    if (downAppearanceEntry != null && downAppearanceEntry.isSubDictionary) {
      downAppearanceEntry = PDAppearanceEntry(createCOSStream());
      appearanceDictionary.downAppearance = downAppearanceEntry;
    }
    downAppearanceEntry ??= PDAppearanceEntry(createCOSStream());
    appearanceDictionary.downAppearance = downAppearanceEntry;

    return downAppearanceEntry;
  }

  /// Get the annotations rollover appearance.
  PDAppearanceEntry getRolloverAppearance() {
    final appearanceDictionary = getAppearance();
    var rolloverAppearanceEntry = appearanceDictionary.rolloverAppearance;

    if (rolloverAppearanceEntry != null &&
        rolloverAppearanceEntry.isSubDictionary) {
      rolloverAppearanceEntry = PDAppearanceEntry(createCOSStream());
      appearanceDictionary.rolloverAppearance = rolloverAppearanceEntry;
    }
    rolloverAppearanceEntry ??= PDAppearanceEntry(createCOSStream());
    appearanceDictionary.rolloverAppearance = rolloverAppearanceEntry;

    return rolloverAppearanceEntry;
  }

  PDRectangle getPaddedRectangle(PDRectangle rectangle, double padding) {
    return PDRectangle(
        rectangle.lowerLeftX + padding,
        rectangle.lowerLeftY + padding,
        rectangle.width - 2 * padding,
        rectangle.height - 2 * padding);
  }

  PDRectangle addRectDifferences(PDRectangle rectangle, List<double>? differences) {
    if (differences == null || differences.length != 4) {
      return rectangle;
    }

    return PDRectangle(
        rectangle.lowerLeftX - differences[0],
        rectangle.lowerLeftY - differences[1],
        rectangle.width + differences[0] + differences[2],
        rectangle.height + differences[1] + differences[3]);
  }

  PDRectangle applyRectDifferences(PDRectangle rectangle, List<double>? differences) {
    if (differences == null || differences.length != 4) {
      return rectangle;
    }
    return PDRectangle(
        rectangle.lowerLeftX + differences[0],
        rectangle.lowerLeftY + differences[1],
        rectangle.width - differences[0] - differences[2],
        rectangle.height - differences[1] - differences[3]);
  }

  void setOpacity(PDAppearanceContentStream contentStream, double opacity) {
    if (opacity < 1) {
      final gs = PDExtendedGraphicsState();
      gs.strokingAlphaConstant = opacity;
      gs.nonStrokingAlphaConstant = opacity;
      contentStream.setGraphicsStateParameters(gs);
    }
  }

  void drawStyle(String style, PDAppearanceContentStream cs, double x, double y,
      double width, bool hasStroke, bool hasBackground, bool ending) {
    final sign = ending ? -1 : 1;
    switch (style) {
      case PDAnnotationLine.leOpenArrow:
      case PDAnnotationLine.leClosedArrow:
        drawArrow(cs, x + sign * width, y, sign * width * 9);
        break;
      case PDAnnotationLine.leButt:
        cs.moveTo(x, y - width * 3);
        cs.lineTo(x, y + width * 3);
        break;
      case PDAnnotationLine.leDiamond:
        drawDiamond(cs, x, y, width * 3);
        break;
      case PDAnnotationLine.leSquare:
        cs.addRect(x - width * 3, y - width * 3, width * 6, width * 6);
        break;
      case PDAnnotationLine.leCircle:
        drawCircle(cs, x, y, width * 3);
        break;
      case PDAnnotationLine.leROpenArrow:
      case PDAnnotationLine.leRClosedArrow:
        drawArrow(cs, x + (-sign) * width, y, (-sign) * width * 9);
        break;
      case PDAnnotationLine.leSlash:
        final width9 = width * 9;
        cs.moveTo(x + (cos(60 * pi / 180) * width9),
            y + (sin(60 * pi / 180) * width9));
        cs.lineTo(x + (cos(240 * pi / 180) * width9),
            y + (sin(240 * pi / 180) * width9));
        break;
      default:
        return;
    }
    if (PDAnnotationLine.leRClosedArrow == style ||
        PDAnnotationLine.leClosedArrow == style) {
      cs.closePath();
    }
    cs.drawShape(width, hasStroke,
        interiorColorStyles.contains(style) && hasBackground);
  }

  void drawArrow(PDAppearanceContentStream cs, double x, double y, double len) {
    final armX = x + (cos(arrowAngle) * len);
    final armYdelta = (sin(arrowAngle) * len);
    cs.moveTo(armX, y + armYdelta);
    cs.lineTo(x, y);
    cs.lineTo(armX, y - armYdelta);
  }

  void drawDiamond(PDAppearanceContentStream cs, double x, double y, double r) {
    cs.moveTo(x - r, y);
    cs.lineTo(x, y + r);
    cs.lineTo(x + r, y);
    cs.lineTo(x, y - r);
    cs.closePath();
  }

  void drawCircle(PDAppearanceContentStream cs, double x, double y, double r) {
    final magic = r * 0.551784;
    cs.moveTo(x, y + r);
    cs.curveTo(x + magic, y + r, x + r, y + magic, x + r, y);
    cs.curveTo(x + r, y - magic, x + magic, y - r, x, y - r);
    cs.curveTo(x - magic, y - r, x - r, y - magic, x - r, y);
    cs.curveTo(x - r, y + magic, x - magic, y + r, x, y + r);
    cs.closePath();
  }

  PDAppearanceEntry getNormalAppearance() {
    final appearanceDictionary = getAppearance();
    var normalAppearanceEntry = appearanceDictionary.normalAppearance;

    if (normalAppearanceEntry == null || normalAppearanceEntry.isSubDictionary) {
      normalAppearanceEntry = PDAppearanceEntry(createCOSStream());
      appearanceDictionary.normalAppearance = normalAppearanceEntry;
    }
    return normalAppearanceEntry;
  }

  PDAppearanceContentStream getAppearanceEntryAsContentStream(
      PDAppearanceEntry appearanceEntry, bool compress) {
    final appearanceStream = appearanceEntry.appearanceStream;
    setTransformationMatrix(appearanceStream);

    var resources = appearanceStream.resources;
    if (resources == null) {
      resources = PDResources();
      appearanceStream.resources = resources;
    }

    return PDAppearanceContentStream(appearanceStream);
  }

  void setTransformationMatrix(PDAppearanceStream appearanceStream) {
    final bbox = getRectangle();
    if (bbox == null) return;
    appearanceStream.boundingBox = bbox;
    final transform =
        Matrix.getTranslateInstance(-bbox.lowerLeftX, -bbox.lowerLeftY);
    appearanceStream.matrix = transform;
  }


  PDRectangle? handleBorderBox(PDAnnotationSquareCircle annotation, double lineWidth) {
    PDRectangle borderBox;
    final rectDifferences = annotation.getRectDifferences();
    final rect = getRectangle();
    if (rect == null) return null;

    if (rectDifferences.isEmpty) {
        borderBox = getPaddedRectangle(rect, lineWidth / 2);
        final diff = lineWidth / 2;
        annotation.setRectDifferences(diff, diff, diff, diff);
        annotation.rect = addRectDifferences(rect, <double>[diff, diff, diff, diff]).toCOSArray().toDoubleList();
        
        final newRect = getRectangle();
        if (newRect != null) {
            final appearanceStream = annotation.getNormalAppearanceStream();
            if (appearanceStream != null) {
                 final transform = Matrix.getTranslateInstance(-newRect.lowerLeftX, -newRect.lowerLeftY);
                 appearanceStream.boundingBox = newRect;
                 appearanceStream.matrix = transform;
            }
        }
    } else {
        borderBox = applyRectDifferences(rect, rectDifferences);
        borderBox = getPaddedRectangle(borderBox, lineWidth / 2);
    }
    return borderBox;
  }
}

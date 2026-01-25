import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_stream.dart';
import '../../common/pd_rectangle.dart';
import '../../pd_form_content_stream.dart';
import '../../pd_resources.dart';
import '../annotation/pd_annotation_widget.dart';
import '../annotation/pd_annotation_appearance.dart';
import '../annotation/pd_appearance_stream.dart';
import 'pd_terminal_field.dart';
import 'pd_variable_text.dart';

class AppearanceGeneratorHelper {
  final PDTerminalField _field;

  AppearanceGeneratorHelper(this._field);

  void setAppearanceValue(String value) {
    final widgets = _field.getWidgets();
    for (final widget in widgets) {
      _generateAppearance(widget, value);
    }
  }

  void _generateAppearance(PDAnnotationWidget widget, String value) {
    var appearance = widget.appearance;
    if (appearance == null) {
      appearance = PDAppearanceDictionary(COSDictionary());
      widget.appearance = appearance;
    }

    var normalAppearance = appearance.normalAppearance;
    PDAppearanceStream appearanceStream;

    if (normalAppearance != null && normalAppearance.isStream) {
      appearanceStream = normalAppearance.appearanceStream;
    } else {
      // Create new appearance stream
      final stream = COSStream();
      appearanceStream = PDAppearanceStream(stream);
      appearance.setNormalAppearanceStream(appearanceStream);
    }

    // Set bounding box
    final rectList = widget.rect;
    final width = (rectList != null && rectList.length >= 4)
        ? rectList[2] - rectList[0]
        : 100.0;
    final height = (rectList != null && rectList.length >= 4)
        ? rectList[3] - rectList[1]
        : 20.0;

    final bbox = PDRectangle(0, 0, width, height);
    appearanceStream.boundingBox = bbox;

    // Create resources if missing
    if (appearanceStream.resources == null) {
      appearanceStream.resources = PDResources(COSDictionary());
    }

    final contentStream = PDFormContentStream(appearanceStream);

    // Parse default appearance string
    String? da = (_field is PDVariableText)
        ? _field.getDefaultAppearance()
        : widget.defaultAppearance;

    COSName? fontName;
    double fontSize = 12;

    if (da != null) {
      final parts = da.split(' ');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i] == 'Tf') {
          if (i >= 2) {
            fontSize = double.tryParse(parts[i - 1]) ?? 12;
            String name = parts[i - 2];
            if (name.startsWith('/')) {
              name = name.substring(1);
            }
            fontName = COSName(name);
          }
        }
      }
    }

    // Ensure font is in resources
    if (fontName != null) {
      // Check if font is in appearance resources
      var font = appearanceStream.resources?.getFont(fontName);
      if (font == null) {
        // Check AcroForm default resources
        final dr = _field.acroForm.defaultResources;
        if (dr != null) {
          font = dr.getFont(fontName);
          if (font != null) {
            // Add to appearance resources
            appearanceStream.resources?.setFont(fontName, font);
          }
        }
      }
    }

    contentStream.saveGraphicsState();

    // Draw background from MK dictionary (appearance characteristics)
    final mk = widget.appearanceCharacteristics;
    if (mk != null) {
      // Draw background color (BG)
      final bgColor = mk.background;
      if (bgColor != null) {
        final components = bgColor.components;
        if (components.length == 1) {
          // Gray
          contentStream.setNonStrokingColorGray(components[0]);
        } else if (components.length == 3) {
          // RGB
          contentStream.setNonStrokingColor(
            components[0], components[1], components[2]);
        } else if (components.length == 4) {
          // CMYK
          contentStream.setNonStrokingColorCMYK(
            components[0], components[1], components[2], components[3]);
        }
        contentStream.rectangle(0, 0, width, height);
        contentStream.fill();
      }
      
      // Draw border color (BC)
      final bcColor = mk.borderColour;
      if (bcColor != null) {
        final components = bcColor.components;
        if (components.length == 1) {
          contentStream.setStrokingColorGray(components[0]);
        } else if (components.length == 3) {
          contentStream.setStrokingColor(
            components[0], components[1], components[2]);
        } else if (components.length == 4) {
          contentStream.setStrokingColorCMYK(
            components[0], components[1], components[2], components[3]);
        }
        contentStream.rectangle(0.5, 0.5, width - 1, height - 1);
        contentStream.stroke();
      }
    }


    // Draw text
    contentStream.beginText();
    if (fontName != null) {
      contentStream.setFont(fontName, fontSize);
    }

    // Position text (simple padding)
    contentStream.newLineAtOffset(2, 2);
    contentStream.showText(value);
    contentStream.endText();

    contentStream.restoreGraphicsState();
    contentStream.close();
  }
}


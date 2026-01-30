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
import '../form/pd_button.dart';
import '../../font/pdfont.dart';

class AppearanceGeneratorHelper {
  final PDTerminalField _field;

  AppearanceGeneratorHelper(this._field);

  void setAppearanceValue(String value) {
    if (_field is PDButton) {
      _updateButtonAppearanceState(value);
    }
    
    final widgets = _field.getWidgets();
    for (final widget in widgets) {
      if (_field is PDButton) {
         // Buttons usually don't need content stream generation if AP is already there,
         // but they might need it if we are creating it from scratch.
         // For now, setting AS is enough for most cases.
      } else {
        _generateAppearance(widget, value);
      }
    }
  }

  void _updateButtonAppearanceState(String value) {
    final widgets = _field.getWidgets();
    for (final widget in widgets) {
      widget.cosObject.setName(COSName('AS'), value);
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
      final stream = COSStream();
      appearanceStream = PDAppearanceStream(stream);
      appearance.setNormalAppearanceStream(appearanceStream);
    }

    final rectList = widget.rect;
    final width = (rectList != null && rectList.length >= 4)
        ? rectList[2] - rectList[0]
        : 100.0;
    final height = (rectList != null && rectList.length >= 4)
        ? rectList[3] - rectList[1]
        : 20.0;

    final bbox = PDRectangle(0, 0, width, height);
    appearanceStream.boundingBox = bbox;

    if (appearanceStream.resources == null) {
      appearanceStream.resources = PDResources(COSDictionary());
    }

    final contentStream = PDFormContentStream(appearanceStream);

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

    PDFont? font;
    if (fontName != null) {
      font = appearanceStream.resources?.getPDFont(fontName);
      if (font == null) {
        final dr = _field.acroForm.defaultResources;
        if (dr != null) {
          font = dr.getPDFont(fontName);
          if (font != null) {
            appearanceStream.resources?.setFont(fontName, font.cosObject);
          }
        }
      }
    }

    contentStream.saveGraphicsState();

    final mk = widget.appearanceCharacteristics;
    if (mk != null) {
      final bgColor = mk.background;
      if (bgColor != null) {
        contentStream.setNonStrokingColorRGB(bgColor);
        contentStream.rectangle(0, 0, width, height);
        contentStream.fill();
      }
      
      final bcColor = mk.borderColour;
      if (bcColor != null) {
        contentStream.setStrokingColorRGB(bcColor);
        contentStream.rectangle(0.5, 0.5, width - 1, height - 1);
        contentStream.stroke();
      }
    }

    // Auto font size calculation
    if (fontSize == 0 && font != null) {
      fontSize = _calculateAutoSize(value, width, height, font);
    }

    contentStream.beginText();
    if (font != null && fontName != null) {
      contentStream.setFont(fontName, fontSize);
    }
    
    // Set text color if specified in DA
    // For now use black as default
    contentStream.setNonStrokingColorGray(0);

    // Calculate text position (centered vertically, left aligned with padding)
    double x = 2;
    double y = (height - fontSize) / 2;
    
    // Support for alignment (Q entry)
    final quadding = (_field is PDVariableText) ? _field.q : 0;
    if (quadding == 1) { // Center
       final textWidth = font?.getStringWidth(value) ?? 0;
       x = (width - (textWidth * fontSize / 1000)) / 2;
    } else if (quadding == 2) { // Right
       final textWidth = font?.getStringWidth(value) ?? 0;
       x = width - (textWidth * fontSize / 1000) - 2;
    }

    contentStream.newLineAtOffset(x, y);
    contentStream.showText(value);
    contentStream.endText();
    contentStream.restoreGraphicsState();
    
    contentStream.close();
  }

  double _calculateAutoSize(String value, double width, double height, PDFont font) {
    // Basic auto-size logic
    double size = 12;
    final textWidth = font.getStringWidth(value);
    if (textWidth > 0) {
      size = (width - 4) * 1000 / textWidth;
    }
    return size.clamp(4.0, height - 4.0);
  }

  // Helper for text fields
  void generateAppearance(String value) {
    final widgets = _field.getWidgets();
    for (final widget in widgets) {
      _generateAppearance(widget, value);
    }
  }
}

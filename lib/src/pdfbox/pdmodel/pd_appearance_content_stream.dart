import 'dart:convert';
import 'dart:typed_data';

import '../cos/cos_array.dart';
import 'graphics/color/pd_color.dart';
import 'interactive/annotation/pd_appearance_stream.dart';
import 'interactive/annotation/pd_border_style_dictionary.dart';
import 'graphics/state/pd_extended_graphics_state.dart';
import 'pd_resources.dart';

/// Provides the ability to write to an appearance content stream.
class PDAppearanceContentStream {
  PDAppearanceContentStream(this.appearance)
      : _resources = appearance.resources ?? PDResources() {
    if (appearance.resources == null) {
      appearance.resources = _resources;
    }
  }

  final PDAppearanceStream appearance;
  final PDResources _resources;
  final BytesBuilder _buffer = BytesBuilder();
  bool _closed = false;

  PDResources get resources => _resources;

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDAppearanceContentStream is closed');
    }
  }

  void _write(String value) {
    final bytes = latin1.encode(value);
    _buffer.add(bytes);
  }

  void _writeOperator(String operator) {
    _ensureOpen();
    _write('$operator\n');
  }

  String _formatNumber(num value) {
    if (value == 0) {
      return '0';
    }
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    var text = value.toStringAsFixed(5);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    if (text.isEmpty || text == '-0') {
      return '0';
    }
    return text;
  }

  void setStrokingColor(List<double> components) {
    _ensureOpen();
    for (final value in components) {
      _write('${_formatNumber(value)} ');
    }
    switch (components.length) {
      case 1:
        _writeOperator('G');
        break;
      case 3:
        _writeOperator('RG');
        break;
      case 4:
        _writeOperator('K');
        break;
    }
  }

  void setNonStrokingColor(List<double> components) {
    _ensureOpen();
    for (final value in components) {
      _write('${_formatNumber(value)} ');
    }
    switch (components.length) {
      case 1:
        _writeOperator('g');
        break;
      case 3:
        _writeOperator('rg');
        break;
      case 4:
        _writeOperator('k');
        break;
    }
  }

  void setLineWidth(double width) {
    _ensureOpen();
    _write('${_formatNumber(width)} w\n');
  }

  void moveTo(double x, double y) {
    _ensureOpen();
    _write('${_formatNumber(x)} ${_formatNumber(y)} m\n');
  }

  void lineTo(double x, double y) {
    _ensureOpen();
    _write('${_formatNumber(x)} ${_formatNumber(y)} l\n');
  }

  void addRect(double x, double y, double width, double height) {
    _ensureOpen();
    _write('${_formatNumber(x)} ${_formatNumber(y)} ${_formatNumber(width)} '
        '${_formatNumber(height)} re\n');
  }

  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _ensureOpen();
    _write('${_formatNumber(x1)} ${_formatNumber(y1)} '
        '${_formatNumber(x2)} ${_formatNumber(y2)} '
        '${_formatNumber(x3)} ${_formatNumber(y3)} c\n');
  }

  void closePath() => _writeOperator('h');

  void stroke() => _writeOperator('S');

  void fill() => _writeOperator('f');

  void fillAndStroke() => _writeOperator('B');

  void drawShape(double lineWidth, bool hasStroke, bool hasFill) {
    if (lineWidth < 1e-6) {
      hasStroke = false;
    }
    if (hasFill && hasStroke) {
      fillAndStroke();
    } else if (hasStroke) {
      stroke();
    } else if (hasFill) {
      fill();
    } else {
      _writeOperator('n'); // End path without filling or stroking
    }
  }
  
  void setGraphicsStateParameters(PDExtendedGraphicsState gs) {
    _ensureOpen();
    var name = resources.addExtGState(gs);
    _write('/${name.name} gs\n');
  }
  
  void setLineDashPattern(List<double> pattern, double phase) {
    _ensureOpen();
    _write('[');
    for (var value in pattern) {
      _write('${_formatNumber(value)} ');
    }
    _write('] ${_formatNumber(phase)} d\n');
  }

  /// Sets stroking color from a PDColor object.
  void setStrokingColorPD(PDColor color) {
    setStrokingColor(color.components);
  }

  /// Sets non-stroking color from a PDColor object.
  void setNonStrokingColorPD(PDColor color) {
    setNonStrokingColor(color.components);
  }

  /// Draws a Form XObject.
  void drawForm(dynamic form) {
    _ensureOpen();
    // form should be a PDFormXObject with a resources.add method pattern
    final name = _resources.add(form);
    _write('/${name.name} Do\n');
  }

  bool setStrokingColorOnDemand(PDColor? color) {
    if (color == null) {
      return false;
    }
    setStrokingColor(color.components);
    return true;
  }

  bool setNonStrokingColorOnDemand(PDColor? color) {
    if (color == null) {
      return false;
    }
    setNonStrokingColor(color.components);
    return true;
  }

  void setBorderLine(double lineWidth, PDBorderStyleDictionary? bs, COSArray? border) {
    if (bs != null && bs.style == PDBorderStyleDictionary.styleDashed) {
      var dash = bs.dashPattern;
      if (dash == null) {
        dash = [3.0];
      }
      setLineDashPattern(dash, 0);
    } else if (bs != null && bs.style == PDBorderStyleDictionary.styleBeveled) {
       // TODO: Implement beveled style if needed, or default
    } else if (bs != null && bs.style == PDBorderStyleDictionary.styleInset) {
        // TODO: Implement inset style if needed
    } else if (bs != null && bs.style == PDBorderStyleDictionary.styleUnderline) {
        // TODO: Implement underline style
    } else if (border != null && border.length >= 4 &&
        border.getObject(3) is COSArray) {
        final dashArray = border.getObject(3) as COSArray;
        setLineDashPattern(dashArray.toDoubleList(), 0);
    }
    
    setLineWidth(lineWidth);
  }

  /// Saves the current graphics state onto the stack (q operator).
  void saveGraphicsState() {
    _ensureOpen();
    _writeOperator('q');
  }

  /// Restores the graphics state from the stack (Q operator).
  void restoreGraphicsState() {
    _ensureOpen();
    _writeOperator('Q');
  }

  /// Concatenates the given matrix to the current transformation matrix (cm operator).
  void transform(double a, double b, double c, double d, double e, double f) {
    _ensureOpen();
    _write('${_formatNumber(a)} ${_formatNumber(b)} ${_formatNumber(c)} '
        '${_formatNumber(d)} ${_formatNumber(e)} ${_formatNumber(f)} cm\n');
  }

  /// Begins a text object (BT operator).
  void beginText() {
    _ensureOpen();
    _writeOperator('BT');
  }

  /// Ends a text object (ET operator).
  void endText() {
    _ensureOpen();
    _writeOperator('ET');
  }

  /// Sets the font and size for text operations.
  void setFont(dynamic font, double size) {
    _ensureOpen();
    final name = _resources.add(font);
    _write('/${name.name} ${_formatNumber(size)} Tf\n');
  }

  /// Moves to the start of the next line, offset from the start of the current line.
  void newLineAtOffset(double tx, double ty) {
    _ensureOpen();
    _write('${_formatNumber(tx)} ${_formatNumber(ty)} Td\n');
  }

  /// Shows the given text string.
  void showText(String text) {
    _ensureOpen();
    // Escape special characters in PDF string
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
    _write('($escaped) Tj\n');
  }

  /// Set the line cap style.
  void setLineCapStyle(int style) {
    _ensureOpen();
    _write('$style J\n');
  }

  /// Set the line join style.
  void setLineJoinStyle(int style) {
    _ensureOpen();
    _write('$style j\n');
  }

  /// Set the miter limit.
  void setMiterLimit(double limit) {
    _ensureOpen();
    _write('${_formatNumber(limit)} M\n');
  }

  /// Clip (W operator) using non-zero winding rule.
  void clip() {
    _ensureOpen();
    _writeOperator('W');
  }

  /// Clip using even-odd rule (W* operator).
  void clipEvenOdd() {
    _ensureOpen();
    _writeOperator('W*');
  }

  /// End path without stroking or filling (n operator).
  void endPath() {
    _ensureOpen();
    _writeOperator('n');
  }

  /// Appends a tiling pattern to the resources and returns its name.
  void setStrokingPattern(dynamic pattern) {
    _ensureOpen();
    final name = _resources.add(pattern);
    _write('/Pattern CS /${name.name} SCN\n');
  }

  /// Sets the non-stroking pattern.
  void setNonStrokingPattern(dynamic pattern) {
    _ensureOpen();
    final name = _resources.add(pattern);
    _write('/Pattern cs /${name.name} scn\n');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final bytes = _buffer.toBytes();
    final stream = appearance.cosObject;
    stream.data = bytes;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import '../cos/cos_name.dart';
import 'graphics/form/pd_form_xobject.dart';
import 'pd_resources.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_stream.dart';

/// Lightweight content stream writer for Form XObjects.
class PDFormContentStream {
  PDFormContentStream(this.formXObject)
      : _buffer = BytesBuilder(copy: false),
        _resources = formXObject.resources ?? PDResources(COSDictionary()) {
    if (formXObject.resources == null) {
      formXObject.resources = _resources;
    }
  }

  final PDFormXObject formXObject;
  final BytesBuilder _buffer;
  final PDResources _resources;

  bool _closed = false;

  bool get isClosed => _closed;

  PDResources get resources => _resources;

  /// Appends raw PDF commands to the stream.
  void writeRaw(String commands) {
    _ensureOpen();
    if (commands.isEmpty) {
      return;
    }
    _write(commands);
  }

  void beginText() => _writeOperator('BT');

  void endText() => _writeOperator('ET');

  void setFont(COSName fontName, double size) {
    _ensureOpen();
    final formatted = _formatNumber(size);
    _write('/${fontName.name} $formatted Tf\n');
  }

  void setLeading(double leading) {
    _ensureOpen();
    _write('${_formatNumber(leading)} TL\n');
  }

  void setTextMatrix(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) {
    _ensureOpen();
    _write('${_formatNumber(a)} ${_formatNumber(b)} ${_formatNumber(c)} '
        '${_formatNumber(d)} ${_formatNumber(e)} ${_formatNumber(f)} Tm\n');
  }

  void moveTextPosition(double tx, double ty) => newLineAtOffset(tx, ty);

  void newLineAtOffset(double tx, double ty) {
    _ensureOpen();
    _write('${_formatNumber(tx)} ${_formatNumber(ty)} Td\n');
  }

  void newLine() => _writeOperator('T*');

  void showText(String text) {
    _ensureOpen();
    _write('${_formatLiteralString(text)} Tj\n');
  }

  void saveGraphicsState() => _writeOperator('q');

  void restoreGraphicsState() => _writeOperator('Q');

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

  void rectangle(double x, double y, double width, double height) {
    _ensureOpen();
    _write('${_formatNumber(x)} ${_formatNumber(y)} ${_formatNumber(width)} '
        '${_formatNumber(height)} re\n');
  }

  void closePath() => _writeOperator('h');

  void stroke() => _writeOperator('S');

  void fill() => _writeOperator('f');

  void setNonStrokingColor(double r, double g, double b) {
    _ensureOpen();
    _write('${_formatNumber(r)} ${_formatNumber(g)} ${_formatNumber(b)} rg\n');
  }
  
  void setNonStrokingColorGray(double gray) {
    _ensureOpen();
    _write('${_formatNumber(gray)} g\n');
  }
  
  void setNonStrokingColorCMYK(double c, double m, double y, double k) {
    _ensureOpen();
    _write('${_formatNumber(c)} ${_formatNumber(m)} ${_formatNumber(y)} ${_formatNumber(k)} k\n');
  }
  
  void setStrokingColor(double r, double g, double b) {
    _ensureOpen();
    _write('${_formatNumber(r)} ${_formatNumber(g)} ${_formatNumber(b)} RG\n');
  }
  
  void setStrokingColorGray(double gray) {
    _ensureOpen();
    _write('${_formatNumber(gray)} G\n');
  }
  
  void setStrokingColorCMYK(double c, double m, double y, double k) {
    _ensureOpen();
    _write('${_formatNumber(c)} ${_formatNumber(m)} ${_formatNumber(y)} ${_formatNumber(k)} K\n');
  }

  /// Appends a cubic Bézier curve (`c` operator) defined by two control points
  /// and an end point.
  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _ensureOpen();
    _write('${_formatNumber(x1)} ${_formatNumber(y1)} '
        '${_formatNumber(x2)} ${_formatNumber(y2)} '
        '${_formatNumber(x3)} ${_formatNumber(y3)} c\n');
  }

  /// Draws a Form XObject.
  void drawForm(PDFormXObject form) {
    _ensureOpen();
    final name = _resources.add(form);
    _write('/${name.name} Do\n');
  }

  /// Alias for rectangle. Adds a rectangle to the path.
  void addRect(double x, double y, double width, double height) {
    rectangle(x, y, width, height);
  }

  /// Sets non-stroking color from a PDColor object.
  void setNonStrokingColorRGB(dynamic color) {
    // Accept PDColor or similar object with components property
    _ensureOpen();
    if (color == null) return;
    final components = color.components as List<double>?;
    if (components == null || components.isEmpty) return;
    if (components.length == 1) {
      setNonStrokingColorGray(components[0]);
    } else if (components.length == 3) {
      setNonStrokingColor(components[0], components[1], components[2]);
    } else if (components.length == 4) {
      setNonStrokingColorCMYK(components[0], components[1], components[2], components[3]);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;

    final bytes = _buffer.toBytes();
    final cosStream = formXObject.cosObject;
    
    // ignore: unnecessary_type_check
    if (cosStream is COSStream) {
      cosStream.data = bytes;
    } else {
      // Should not happen for PDFormXObject
      throw StateError('PDFormXObject cosObject is not a COSStream');
    }
  }

  void _writeOperator(String operator) {
    _ensureOpen();
    _write('$operator\n');
  }

  void _write(String value) {
    final bytes = latin1.encode(value);
    _buffer.add(bytes);
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDFormContentStream is closed');
    }
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

  String _formatLiteralString(String text) {
    final buffer = StringBuffer('(');
    for (final codeUnit in text.codeUnits) {
      switch (codeUnit) {
        case 0x08:
          buffer.write('\\b');
          break;
        case 0x09:
          buffer.write('\\t');
          break;
        case 0x0a:
          buffer.write('\\n');
          break;
        case 0x0c:
          buffer.write('\\f');
          break;
        case 0x0d:
          buffer.write('\\r');
          break;
        case 0x28:
          buffer.write('\\(');
          break;
        case 0x29:
          buffer.write('\\)');
          break;
        case 0x5c:
          buffer.write('\\\\');
          break;
        default:
          if (codeUnit < 32 || codeUnit > 126) {
            final octal = codeUnit.toRadixString(8).padLeft(3, '0');
            buffer.write('\\$octal');
          } else {
            buffer.writeCharCode(codeUnit);
          }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }
}


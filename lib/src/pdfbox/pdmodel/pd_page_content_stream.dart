import 'dart:convert';
import 'dart:typed_data';

import '../cos/cos_name.dart';
import 'pd_document.dart';
import 'pd_page.dart';
import 'pd_resources.dart';
import 'pd_stream.dart';

/// Defines how newly written content should be combined with existing page data.
enum PDPageContentMode {
  /// Replaces any existing content streams.
  overwrite,

  /// Appends the new content stream after existing ones.
  append,

  /// Inserts the new content stream before existing ones.
  prepend,
}

/// Lightweight content stream writer supporting common drawing operations.
class PDPageContentStream {
  PDPageContentStream(
    this.document,
    this.page, {
    this.mode = PDPageContentMode.overwrite,
  })  : _buffer = BytesBuilder(copy: false),
        _resources = page.resources {
    page.resources = _resources;
  }

  final PDDocument document;
  final PDPage page;
  final PDPageContentMode mode;
  final BytesBuilder _buffer;
  final PDResources _resources;

  bool _closed = false;
  int _byteLength = 0;

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

  /// Appends raw bytes to the stream without any validation.
  void writeRawBytes(List<int> bytes) {
    _ensureOpen();
    if (bytes.isEmpty) {
      return;
    }
    final data = Uint8List.fromList(bytes);
    _buffer.add(data);
    _byteLength += data.length;
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

  /// Shows text with individual glyph positioning adjustments using the `TJ`
  /// operator. The [elements] sequence may contain `String` instances for
  /// literal text segments or numeric values representing glyph displacements
  /// in text space units.
  void showTextWithPositioning(Iterable<Object?> elements) {
    _ensureOpen();
    final buffer = StringBuffer('[');
    var first = true;
    for (final element in elements) {
      if (!first) {
        buffer.write(' ');
      }
      first = false;
      if (element is String) {
        buffer.write(_formatLiteralString(element));
      } else if (element is num) {
        buffer.write(_formatNumber(element));
      } else {
        throw ArgumentError(
          'Unsupported TJ element ${element.runtimeType}; expected String or num.',
        );
      }
    }
    buffer.write('] TJ\n');
    _write(buffer.toString());
  }

  void showTextLines(Iterable<String> lines) {
    var first = true;
    for (final line in lines) {
      if (!first) {
        newLine();
      }
      showText(line);
      first = false;
    }
  }

  /// Sets the text leading automatically based on the [fontSize] and an
  /// optional scaling [factor] (default 1.2).
  void setAutoLeading(double fontSize, {double factor = 1.2}) {
    if (fontSize <= 0) {
      throw ArgumentError.value(fontSize, 'fontSize', 'must be positive');
    }
    if (factor <= 0) {
      throw ArgumentError.value(factor, 'factor', 'must be positive');
    }
    setLeading(fontSize * factor);
  }

  /// Writes a paragraph by emitting each line in [text] and advancing the text
  /// position between lines. Line endings are normalised to LF. By default a
  /// trailing line break is appended via [trailingLineBreaks].
  void showParagraph(String text, {int trailingLineBreaks = 1}) {
    if (trailingLineBreaks < 0) {
      throw ArgumentError.value(
        trailingLineBreaks,
        'trailingLineBreaks',
        'must be >= 0',
      );
    }
    _ensureOpen();
    final lines = _splitParagraphLines(text);
    for (var index = 0; index < lines.length; index++) {
      if (index > 0) {
        newLine();
      }
      showText(lines[index]);
    }
    for (var i = 0; i < trailingLineBreaks; i++) {
      newLine();
    }
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

  /// Appends a cubic Bézier curve (`c` operator) defined by two control points
  /// and an end point.
  void curveTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    _ensureOpen();
    _write('${_formatNumber(x1)} ${_formatNumber(y1)} '
        '${_formatNumber(x2)} ${_formatNumber(y2)} '
        '${_formatNumber(x3)} ${_formatNumber(y3)} c\n');
  }

  /// Appends a cubic Bézier curve (`v` operator) sharing the initial control
  /// point with the current point.
  void curveToV(double x2, double y2, double x3, double y3) {
    _ensureOpen();
    _write('${_formatNumber(x2)} ${_formatNumber(y2)} '
        '${_formatNumber(x3)} ${_formatNumber(y3)} v\n');
  }

  /// Appends a cubic Bézier curve (`y` operator) reusing the second control
  /// point as the end point.
  void curveToY(double x1, double y1, double x3, double y3) {
    _ensureOpen();
    _write('${_formatNumber(x1)} ${_formatNumber(y1)} '
        '${_formatNumber(x3)} ${_formatNumber(y3)} y\n');
  }

  void closePath() => _writeOperator('h');

  void stroke() => _writeOperator('S');

  void fill() => _writeOperator('f');

  void fillEvenOdd() => _writeOperator('f*');

  void closeAndStroke() => _writeOperator('s');

  /// Applies the supplied transformation matrix using the `cm` operator.
  void transform(double a, double b, double c, double d, double e, double f) {
    _ensureOpen();
    _write('${_formatNumber(a)} ${_formatNumber(b)} ${_formatNumber(c)} '
        '${_formatNumber(d)} ${_formatNumber(e)} ${_formatNumber(f)} cm\n');
  }

  /// Draws an image XObject previously registered in the page resources.
  void drawImage(COSName name) {
    _ensureOpen();
    _write('/${name.name} Do\n');
  }

  List<String> _splitParagraphLines(String text) {
    if (text.isEmpty) {
      return const <String>[];
    }
    final normalised = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalised.split('\n');
  }
  void setStrokingColorRgb(double r, double g, double b) {
    _ensureOpen();
    _write('${_formatNumber(r)} ${_formatNumber(g)} ${_formatNumber(b)} RG\n');
  }

  void setNonStrokingColorRgb(double r, double g, double b) {
    _ensureOpen();
    _write('${_formatNumber(r)} ${_formatNumber(g)} ${_formatNumber(b)} rg\n');
  }

  void writeComment(String comment) {
    _ensureOpen();
    _write('%$comment\n');
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;

    if (_byteLength == 0) {
      if (mode == PDPageContentMode.overwrite) {
        page.setContentStream(PDStream.fromBytes(Uint8List(0)));
      }
      return;
    }

    final stream = PDStream.fromBytes(_buffer.toBytes());
    switch (mode) {
      case PDPageContentMode.overwrite:
        page.setContentStream(stream);
        break;
      case PDPageContentMode.append:
        page.appendContentStream(stream);
        break;
      case PDPageContentMode.prepend:
        final existing = page.contentStreams.toList();
        existing.insert(0, stream);
        page.setContentStreams(existing);
        break;
    }
  }

  void dispose() => close();

  void _writeOperator(String operator) {
    _ensureOpen();
    _write('$operator\n');
  }

  void _write(String value) {
    final bytes = latin1.encode(value);
    _buffer.add(bytes);
    _byteLength += bytes.length;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDPageContentStream is closed');
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

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

  void close() {
    if (_closed) return;
    _closed = true;
    final bytes = _buffer.toBytes();
    final stream = appearance.cosObject;
    stream.data = bytes;
  }
}

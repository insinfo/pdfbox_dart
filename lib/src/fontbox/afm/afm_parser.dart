import 'dart:convert';
import 'dart:typed_data';

import '../util/bounding_box.dart';
import 'char_metric.dart';
import 'composite.dart';
import 'composite_part.dart';
import 'font_metrics.dart';
import 'kern_pair.dart';
import 'ligature.dart';
import 'track_kern.dart';

class AFMParser {
  AFMParser(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  static const String comment = 'Comment';
  static const String startFontMetrics = 'StartFontMetrics';
  static const String endFontMetrics = 'EndFontMetrics';
  static const String fontName = 'FontName';
  static const String fullName = 'FullName';
  static const String familyName = 'FamilyName';
  static const String weight = 'Weight';
  static const String fontBBox = 'FontBBox';
  static const String version = 'Version';
  static const String notice = 'Notice';
  static const String encodingScheme = 'EncodingScheme';
  static const String mappingScheme = 'MappingScheme';
  static const String escChar = 'EscChar';
  static const String characterSet = 'CharacterSet';
  static const String characters = 'Characters';
  static const String isBaseFont = 'IsBaseFont';
  static const String vVector = 'VVector';
  static const String isFixedV = 'IsFixedV';
  static const String capHeight = 'CapHeight';
  static const String xHeight = 'XHeight';
  static const String ascender = 'Ascender';
  static const String descender = 'Descender';
  static const String underlinePosition = 'UnderlinePosition';
  static const String underlineThickness = 'UnderlineThickness';
  static const String italicAngle = 'ItalicAngle';
  static const String charWidth = 'CharWidth';
  static const String isFixedPitch = 'IsFixedPitch';
  static const String startCharMetrics = 'StartCharMetrics';
  static const String endCharMetrics = 'EndCharMetrics';
  static const String charmetricsC = 'C';
  static const String charmetricsCh = 'CH';
  static const String charmetricsWx = 'WX';
  static const String charmetricsW0x = 'W0X';
  static const String charmetricsW1x = 'W1X';
  static const String charmetricsWy = 'WY';
  static const String charmetricsW0y = 'W0Y';
  static const String charmetricsW1y = 'W1Y';
  static const String charmetricsW = 'W';
  static const String charmetricsW0 = 'W0';
  static const String charmetricsW1 = 'W1';
  static const String charmetricsVv = 'VV';
  static const String charmetricsN = 'N';
  static const String charmetricsB = 'B';
  static const String charmetricsL = 'L';
  static const String stdHW = 'StdHW';
  static const String stdVW = 'StdVW';
  static const String startTrackKern = 'StartTrackKern';
  static const String endTrackKern = 'EndTrackKern';
  static const String startKernData = 'StartKernData';
  static const String endKernData = 'EndKernData';
  static const String startKernPairs = 'StartKernPairs';
  static const String endKernPairs = 'EndKernPairs';
  static const String startKernPairs0 = 'StartKernPairs0';
  static const String startKernPairs1 = 'StartKernPairs1';
  static const String startComposites = 'StartComposites';
  static const String endComposites = 'EndComposites';
  static const String cc = 'CC';
  static const String pcc = 'PCC';
  static const String kernPairKp = 'KP';
  static const String kernPairKph = 'KPH';
  static const String kernPairKpx = 'KPX';
  static const String kernPairKpy = 'KPY';

  static const int _bitsInHex = 16;

  final Uint8List _bytes;
  int _offset = 0;

  FontMetrics parse({bool reducedDataset = false}) {
    _offset = 0;
    try {
      return _parseFontMetrics(reducedDataset);
    } on StateError {
      throw FormatException('Unexpected EOF while parsing AFM');
    } on RangeError {
      throw FormatException('Unexpected EOF while parsing AFM');
    } on FormatException {
      rethrow;
    }
  }

  FontMetrics _parseFontMetrics(bool reducedDataset) {
    _readCommand(startFontMetrics);
    final metrics = FontMetrics();
    metrics.setAFMVersion(_readFloat());
    String nextCommand;
    var charMetricsRead = false;
    while ((nextCommand = _readString()) != endFontMetrics) {
      switch (nextCommand) {
        case fontName:
          metrics.setFontName(_readLine());
          break;
        case fullName:
          metrics.setFullName(_readLine());
          break;
        case familyName:
          metrics.setFamilyName(_readLine());
          break;
        case weight:
          metrics.setWeight(_readLine());
          break;
        case fontBBox:
          final box = BoundingBox();
          box.lowerLeftX = _readFloat();
          box.lowerLeftY = _readFloat();
          box.upperRightX = _readFloat();
          box.upperRightY = _readFloat();
          metrics.setFontBBox(box);
          break;
        case version:
          metrics.setFontVersion(_readLine());
          break;
        case notice:
          metrics.setNotice(_readLine());
          break;
        case encodingScheme:
          metrics.setEncodingScheme(_readLine());
          break;
        case mappingScheme:
          metrics.setMappingScheme(_readInt());
          break;
        case escChar:
          metrics.setEscChar(_readInt());
          break;
        case characterSet:
          metrics.setCharacterSet(_readLine());
          break;
        case characters:
          metrics.setCharacters(_readInt());
          break;
        case isBaseFont:
          metrics.setIsBaseFont(_readBoolean());
          break;
        case vVector:
          metrics.setVVector(<double>[_readFloat(), _readFloat()]);
          break;
        case isFixedV:
          metrics.setIsFixedV(_readBoolean());
          break;
        case capHeight:
          metrics.setCapHeight(_readFloat());
          break;
        case xHeight:
          metrics.setXHeight(_readFloat());
          break;
        case ascender:
          metrics.setAscender(_readFloat());
          break;
        case descender:
          metrics.setDescender(_readFloat());
          break;
        case stdHW:
          metrics.setStandardHorizontalWidth(_readFloat());
          break;
        case stdVW:
          metrics.setStandardVerticalWidth(_readFloat());
          break;
        case comment:
          metrics.addComment(_readLine());
          break;
        case underlinePosition:
          metrics.setUnderlinePosition(_readFloat());
          break;
        case underlineThickness:
          metrics.setUnderlineThickness(_readFloat());
          break;
        case italicAngle:
          metrics.setItalicAngle(_readFloat());
          break;
        case charWidth:
          metrics.setCharWidth(<double>[_readFloat(), _readFloat()]);
          break;
        case isFixedPitch:
          metrics.setFixedPitch(_readBoolean());
          break;
        case startCharMetrics:
          charMetricsRead = _parseCharMetrics(metrics);
          break;
        case startKernData:
          if (!reducedDataset) {
            _parseKernData(metrics);
          }
          break;
        case startComposites:
          if (!reducedDataset) {
            _parseComposites(metrics);
          }
          break;
        default:
          if (!reducedDataset || !charMetricsRead) {
            throw FormatException("Unknown AFM key '$nextCommand'");
          }
      }
    }
    return metrics;
  }

  void _parseKernData(FontMetrics metrics) {
    String nextCommand;
    while ((nextCommand = _readString()) != endKernData) {
      switch (nextCommand) {
        case startTrackKern:
          final count = _readInt();
          for (var i = 0; i < count; i++) {
            metrics.addTrackKern(
              TrackKern(_readInt(), _readFloat(), _readFloat(), _readFloat(), _readFloat()),
            );
          }
          _readCommand(endTrackKern);
          break;
        case startKernPairs:
          _parseKernPairs(metrics.addKernPair);
          break;
        case startKernPairs0:
          _parseKernPairs(metrics.addKernPair0);
          break;
        case startKernPairs1:
          _parseKernPairs(metrics.addKernPair1);
          break;
        default:
          throw FormatException("Unknown kerning data type '$nextCommand'");
      }
    }
  }

  void _parseKernPairs(void Function(KernPair) sink) {
    final count = _readInt();
    for (var i = 0; i < count; i++) {
      sink(_parseKernPair());
    }
    _readCommand(endKernPairs);
  }

  KernPair _parseKernPair() {
    final cmd = _readString();
    switch (cmd) {
      case kernPairKp:
        return KernPair(_readString(), _readString(), _readFloat(), _readFloat());
      case kernPairKph:
        return KernPair(_hexToString(_readString()), _hexToString(_readString()), _readFloat(),
            _readFloat());
      case kernPairKpx:
        return KernPair(_readString(), _readString(), _readFloat(), 0);
      case kernPairKpy:
        return KernPair(_readString(), _readString(), 0, _readFloat());
      default:
        throw FormatException("Error expected kern pair command actual='$cmd'");
    }
  }

  void _parseComposites(FontMetrics metrics) {
    final count = _readInt();
    for (var i = 0; i < count; i++) {
      metrics.addComposite(_parseComposite());
    }
    _readCommand(endComposites);
  }

  Composite _parseComposite() {
    final tokens = _tokenize(_readLine());
    if (tokens.isEmpty) {
      throw FormatException('Composite definition is empty');
    }
    var index = 0;

    String next() {
      if (index >= tokens.length) {
        throw FormatException('Incomplete composite definition');
      }
      return tokens[index++];
    }

    final ccValue = next();
    if (ccValue != cc) {
      throw FormatException("Expected '$cc' actual '$ccValue'");
    }
    final composite = Composite(next());
    final partCount = _parseInt(next());
    for (var i = 0; i < partCount; i++) {
      final partToken = next();
      if (partToken != pcc) {
        throw FormatException("Expected '$pcc' actual '$partToken'");
      }
      final name = next();
      final x = _parseInt(next());
      final y = _parseInt(next());
      composite.addPart(CompositePart(name, x, y));
    }
    return composite;
  }

  bool _parseCharMetrics(FontMetrics metrics) {
    final count = _readInt();
    for (var i = 0; i < count; i++) {
      metrics.addCharMetric(_parseCharMetric());
    }
    _readCommand(endCharMetrics);
    return true;
  }

  CharMetric _parseCharMetric() {
    final line = _readLine();
    final entries = line.split(';');
    final metric = CharMetric();
    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final parts = trimmed.split(RegExp(r'\s+'));
      final command = parts.first;
      final values = parts.skip(1).toList();
      switch (command) {
        case charmetricsC:
          metric.setCharacterCode(_parseInt(values.first));
          break;
        case charmetricsWx:
          metric.setWx(_parseFloat(values.first));
          break;
        case charmetricsN:
          metric.setName(values.first);
          break;
        case charmetricsB:
          if (values.length != 4) {
            throw FormatException('Bounding box requires four values');
          }
          final box = BoundingBox();
          box.lowerLeftX = _parseFloat(values[0]);
          box.lowerLeftY = _parseFloat(values[1]);
          box.upperRightX = _parseFloat(values[2]);
          box.upperRightY = _parseFloat(values[3]);
          metric.setBoundingBox(box);
          break;
        case charmetricsL:
          if (values.length != 2) {
            throw FormatException('Ligature requires successor and ligature');
          }
          metric.addLigature(Ligature(values[0], values[1]));
          break;
        case charmetricsCh:
          metric.setCharacterCode(_parseInt(values.first, _bitsInHex));
          break;
        case charmetricsW0x:
          metric.setW0x(_parseFloat(values.first));
          break;
        case charmetricsW1x:
          metric.setW1x(_parseFloat(values.first));
          break;
        case charmetricsWy:
          metric.setWy(_parseFloat(values.first));
          break;
        case charmetricsW0y:
          metric.setW0y(_parseFloat(values.first));
          break;
        case charmetricsW1y:
          metric.setW1y(_parseFloat(values.first));
          break;
        case charmetricsW:
          metric.setW(_parseFloatPair(values));
          break;
        case charmetricsW0:
          metric.setW0(_parseFloatPair(values));
          break;
        case charmetricsW1:
          metric.setW1(_parseFloatPair(values));
          break;
        case charmetricsVv:
          metric.setVv(_parseFloatPair(values));
          break;
        default:
          throw FormatException("Unknown CharMetrics command '$command'");
      }
    }
    return metric;
  }

  List<double> _parseFloatPair(List<String> values) {
    if (values.length != 2) {
      throw FormatException('Expected two numeric values');
    }
    return <double>[_parseFloat(values[0]), _parseFloat(values[1])];
  }

  String _hexToString(String value) {
    if (value.length < 2) {
      throw FormatException('Hex string must be at least two characters long');
    }
    if (!value.startsWith('<') || !value.endsWith('>')) {
      throw FormatException("Hex string must be wrapped in angle brackets '$value'");
    }
    final hex = value.substring(1, value.length - 1);
    if (hex.length.isOdd) {
      throw FormatException('Hex string must contain an even number of digits');
    }
    final data = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      data[i ~/ 2] = _parseInt(hex.substring(i, i + 2), _bitsInHex);
    }
    return latin1.decode(data);
  }

  List<String> _tokenize(String source) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    }

    for (var i = 0; i < source.length; i++) {
      final ch = source.codeUnitAt(i);
      if (ch == 0x3B || ch == 0x20 || ch == 0x09) { // ;, space, tab
        flush();
      } else {
        buffer.writeCharCode(ch);
      }
    }
    flush();
    return tokens;
  }

  void _readCommand(String expected) {
    final actual = _readString();
    if (actual != expected) {
      throw FormatException("Expected '$expected' actual '$actual'");
    }
  }

  bool _readBoolean() => _readString().toLowerCase() == 'true';

  int _readInt() => _parseInt(_readString());

  double _readFloat() => _parseFloat(_readString());

  String _readLine() {
    final buffer = StringBuffer();
    final first = _readSkippingWhitespace();
    buffer.writeCharCode(first);
    while (_offset < _bytes.length) {
      final next = _readByte();
      if (_isEol(next)) {
        if (next == 0x0D && _offset < _bytes.length && _bytes[_offset] == 0x0A) {
          _offset++;
        }
        break;
      }
      buffer.writeCharCode(next);
    }
    return buffer.toString();
  }

  String _readString() {
    final buffer = StringBuffer();
    final first = _readSkippingWhitespace();
    buffer.writeCharCode(first);
    while (_offset < _bytes.length) {
      final next = _readByte();
      if (_isWhitespace(next)) {
        break;
      }
      buffer.writeCharCode(next);
    }
    return buffer.toString();
  }

  int _readSkippingWhitespace() {
    while (true) {
      final value = _readByte();
      if (!_isWhitespace(value)) {
        return value;
      }
    }
  }

  int _readByte() {
    if (_offset >= _bytes.length) {
      throw StateError('No more data');
    }
    return _bytes[_offset++];
  }

  bool _isWhitespace(int value) {
    return value == 0x20 || value == 0x09 || value == 0x0D || value == 0x0A;
  }

  bool _isEol(int value) => value == 0x0D || value == 0x0A;

  int _parseInt(String value, [int radix = 10]) {
    try {
      return int.parse(value, radix: radix);
    } on FormatException catch (error) {
      throw FormatException('Error parsing integer: ${error.message}');
    }
  }

  double _parseFloat(String value) {
    try {
      return double.parse(value);
    } on FormatException catch (error) {
      throw FormatException('Error parsing float: ${error.message}');
    }
  }
}

import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../ttf/font_headers.dart';
import 'cff_charset.dart';
import 'cff_encoding.dart';
import 'cff_expert_charset.dart';
import 'cff_expert_encoding.dart';
import 'cff_expert_subset_charset.dart';
import 'cff_font.dart';
import 'cff_iso_adobe_charset.dart';
import 'cff_operator.dart';
import 'cff_standard_encoding.dart';
import 'cff_standard_string.dart';
import 'data_input.dart';
import 'data_input_byte_array.dart';
import 'data_input_random_access_read.dart';

/// Parses Compact Font Format (CFF) and Type 1C programs, producing [CFFFont]
/// instances compatible with the PDFBox APIs.
class CffParser {
  CffParser();

  CFFByteSource? _source;
  late List<String> _stringIndex;

  /// Parses a CFF program from [bytes].
  List<CFFFont> parse(Uint8List bytes, {CFFByteSource? byteSource}) {
    _source = byteSource ?? _InMemoryByteSource(bytes);
    final input = DataInputByteArray(bytes);
    return _parse(input);
  }

  /// Extracts ROS values from the first subfont of a CFF dataset.
  void parseFirstSubFontRos(RandomAccessRead source, FontHeaders outHeaders) {
    source.seek(0);
    final input = DataInputRandomAccessRead(source);
    final dataInput = _skipHeader(input);
    final nameIndex = _readStringIndexData(dataInput);
    if (nameIndex.isEmpty) {
      outHeaders.setError('Name index missing in CFF font');
      return;
    }

    final topDictIndex = _readIndexData(dataInput);
    if (topDictIndex.isEmpty) {
      outHeaders.setError('Top DICT INDEX missing in CFF font');
      return;
    }

    _stringIndex = _readStringIndexData(dataInput);
    final topDict = _readDictData(DataInputByteArray(topDictIndex.first));

    final syntheticBase = topDict.getEntry('SyntheticBase');
    if (syntheticBase != null) {
      outHeaders.setError('Synthetic fonts are not supported');
      return;
    }

    final cidFont = _parseRos(topDict);
    if (cidFont != null) {
      outHeaders.setOtfRos(cidFont.registry, cidFont.ordering, cidFont.supplement);
    }
  }

  List<CFFFont> _parse(DataInput input) {
    input = _skipHeader(input);
    final nameIndex = _readStringIndexData(input);
    if (nameIndex.isEmpty) {
      throw IOException('Name index missing in CFF font');
    }

    final topDictIndex = _readIndexData(input);
    if (topDictIndex.isEmpty) {
      throw IOException('Top DICT INDEX missing in CFF font');
    }

    _stringIndex = _readStringIndexData(input);
    final globalSubrIndex = _readIndexData(input);

    final fonts = <CFFFont>[];
    for (var i = 0; i < nameIndex.length; i++) {
      final font = _parseFont(
        input,
        nameIndex[i],
        topDictIndex[i],
        globalSubrIndex,
      );
      fonts.add(font);
    }
    return fonts;
  }

  DataInput _skipHeader(DataInput input) {
    final tag = _readTagName(input);
    switch (tag) {
      case _tagOtto:
        input = _createTaggedCffInput(input);
        break;
      case _tagTtcf:
        throw IOException('OpenType collections are not supported yet');
      case _tagTtfOnly:
        throw IOException('TrueType outlines embedded in OTTO are unsupported');
      default:
        input.setPosition(0);
    }

    _readHeader(input);
    return input;
  }

  CFFFont _parseFont(
    DataInput input,
    String name,
    Uint8List topDictData,
    List<Uint8List> globalSubrIndex,
  ) {
    final topDict = _readDictData(DataInputByteArray(topDictData));

    final syntheticBase = topDict.getEntry('SyntheticBase');
    if (syntheticBase != null) {
      throw IOException('Synthetic fonts are not supported');
    }

  final cidFont = _parseRos(topDict);
  final isCid = cidFont != null;
  final CFFFont font = cidFont ?? CFFType1Font();
    font.name = name;

    _populateTopDict(font, topDict);

    final charStringsEntry = topDict.getEntry('CharStrings');
    if (charStringsEntry == null || !charStringsEntry.hasOperands) {
      throw IOException('CharStrings is missing or empty');
    }
    final charStringsOffset = charStringsEntry.numbers.first.toInt();
    input.setPosition(charStringsOffset);
    final charStringsIndex = _readIndexData(input);
    font.charStrings = charStringsIndex;

    font.charset = _readCharset(input, topDict, charStringsIndex.length, isCid);

    if (cidFont != null) {
      _parseCidDictionaries(
        input,
        topDict,
        cidFont,
        charStringsIndex.length,
      );
    } else {
      _parseType1Dictionaries(input, topDict, font as CFFType1Font);
    }

    font.globalSubrIndex = globalSubrIndex;
    font.setByteSource(_source!);
    return font;
  }

  void _populateTopDict(CFFFont font, _DictData topDict) {
    void add(String key, Object? value) {
      if (value != null) {
        font.topDict[key] = value;
      }
    }

    add('version', _readStringOperand(topDict, 'version'));
    add('Notice', _readStringOperand(topDict, 'Notice'));
    add('Copyright', _readStringOperand(topDict, 'Copyright'));
    add('FullName', _readStringOperand(topDict, 'FullName'));
    add('FamilyName', _readStringOperand(topDict, 'FamilyName'));
    add('Weight', _readStringOperand(topDict, 'Weight'));
    add('isFixedPitch', topDict.getBoolean('isFixedPitch', false));
    add('ItalicAngle', topDict.getNumber('ItalicAngle', 0));
    add('UnderlinePosition', topDict.getNumber('UnderlinePosition', -100));
    add('UnderlineThickness', topDict.getNumber('UnderlineThickness', 50));
    add('PaintType', topDict.getNumber('PaintType', 0));
    add('CharstringType', topDict.getNumber('CharstringType', 2));
    add('FontMatrix',
        topDict.getArray('FontMatrix', const <num>[0.001, 0.0, 0.0, 0.001, 0.0, 0.0]));
    add('UniqueID', topDict.getNumber('UniqueID', null));
    add('FontBBox', topDict.getArray('FontBBox', const <num>[0, 0, 0, 0]));
    add('StrokeWidth', topDict.getNumber('StrokeWidth', 0));
    add('XUID', topDict.getArray('XUID', null));
  }

  CFFCharset _readCharset(
    DataInput input,
    _DictData topDict,
    int numGlyphs,
    bool isCid,
  ) {
    final charsetEntry = topDict.getEntry('charset');
    if (charsetEntry != null && charsetEntry.hasOperands) {
      final charsetOffset = charsetEntry.numbers.first.toInt();
      if (!isCid && charsetOffset == 0) {
        return CFFISOAdobeCharset.instance;
      }
      if (!isCid && charsetOffset == 1) {
        return CFFExpertCharset.instance;
      }
      if (!isCid && charsetOffset == 2) {
        return CFFExpertSubsetCharset.instance;
      }
      if (numGlyphs == 0) {
        return _EmptyCharsetType1();
      }
      input.setPosition(charsetOffset);
      return _readEmbeddedCharset(input, numGlyphs, isCid);
    }

    return isCid ? _EmptyCharsetCID(numGlyphs) : CFFISOAdobeCharset.instance;
  }

  void _parseType1Dictionaries(
    DataInput input,
    _DictData topDict,
    CFFType1Font font,
  ) {
    font.encoding = _readEncoding(input, topDict, font.charset);

    final privateEntry = topDict.getEntry('Private');
    if (privateEntry == null || privateEntry.numbers.length < 2) {
      throw IOException('Private dictionary missing for font ${font.name}');
    }
  final int privateSize = privateEntry.numbers[0].toInt();
  final int privateOffset = privateEntry.numbers[1].toInt();
  final _DictData privateDict =
    _readDictDataRange(input, privateOffset, privateSize);

    final privateMap = _readPrivateDict(privateDict);
    privateMap.forEach(font.addPrivateEntry);

    final int subrsOffset = privateDict.getNumber('Subrs', 0)?.toInt() ?? 0;
    if (subrsOffset > 0) {
      input.setPosition(privateOffset + subrsOffset);
      font.privateDict['Subrs'] = _readIndexData(input);
    }
  }

  void _parseCidDictionaries(
    DataInput input,
    _DictData topDict,
    CFFCIDFont font,
    int numGlyphs,
  ) {
    final fdArrayEntry = topDict.getEntry('FDArray');
    if (fdArrayEntry == null || fdArrayEntry.numbers.isEmpty) {
      throw IOException('FDArray missing for CID-keyed font');
    }
    final fdArrayOffset = fdArrayEntry.numbers.first.toInt();
    input.setPosition(fdArrayOffset);
    final fdArray = _readIndexData(input);
    if (fdArray.isEmpty) {
      throw IOException('FDArray empty for CID-keyed font');
    }

    final fontDicts = <Map<String, Object?>>[];
    final privateDicts = <Map<String, Object?>>[];

    for (final bytes in fdArray) {
      final fdDict = _readDictData(DataInputByteArray(bytes));
      fontDicts.add(<String, Object?>{
        'FontName': _readStringOperand(fdDict, 'FontName'),
        'FontType': fdDict.getNumber('FontType', 0),
        'FontBBox': fdDict.getArray('FontBBox', null),
        'FontMatrix': fdDict.getArray('FontMatrix', null),
      });

      final privateEntry = fdDict.getEntry('Private');
      if (privateEntry == null || privateEntry.numbers.length < 2) {
        privateDicts.add(<String, Object?>{});
        continue;
      }
      final int privateSize = privateEntry.numbers[0].toInt();
      final int privateOffset = privateEntry.numbers[1].toInt();
      final _DictData privateDict =
          _readDictDataRange(input, privateOffset, privateSize);
      final privateMap = _readPrivateDict(privateDict);

      final int subrsOffset = privateDict.getNumber('Subrs', 0)?.toInt() ?? 0;
      if (subrsOffset > 0) {
        input.setPosition(privateOffset + subrsOffset);
        privateMap['Subrs'] = _readIndexData(input);
      }
      privateDicts.add(privateMap);
    }

    font.fontDicts = fontDicts;
    font.privateDicts = privateDicts;

    final fdSelectEntry = topDict.getEntry('FDSelect');
    if (fdSelectEntry == null || fdSelectEntry.numbers.isEmpty) {
      throw IOException('FDSelect missing for CID-keyed font');
    }
    final fdSelectOffset = fdSelectEntry.numbers.first.toInt();
    input.setPosition(fdSelectOffset);
    font.fdSelect = _readFdSelect(input, numGlyphs);
  }

  Map<String, Object?> _readPrivateDict(_DictData dict) {
    final map = <String, Object?>{
      'BlueValues': dict.getDelta('BlueValues'),
      'OtherBlues': dict.getDelta('OtherBlues'),
      'FamilyBlues': dict.getDelta('FamilyBlues'),
      'FamilyOtherBlues': dict.getDelta('FamilyOtherBlues'),
      'BlueScale': dict.getNumber('BlueScale', 0.039625),
      'BlueShift': dict.getNumber('BlueShift', 7),
      'BlueFuzz': dict.getNumber('BlueFuzz', 1),
      'StdHW': dict.getNumber('StdHW', null),
      'StdVW': dict.getNumber('StdVW', null),
      'StemSnapH': dict.getDelta('StemSnapH'),
      'StemSnapV': dict.getDelta('StemSnapV'),
      'ForceBold': dict.getBoolean('ForceBold', false),
      'LanguageGroup': dict.getNumber('LanguageGroup', 0),
      'ExpansionFactor': dict.getNumber('ExpansionFactor', 0.06),
      'initialRandomSeed': dict.getNumber('initialRandomSeed', 0),
      'defaultWidthX': dict.getNumber('defaultWidthX', 0),
      'nominalWidthX': dict.getNumber('nominalWidthX', 0),
    };
    map.removeWhere((_, value) => value == null);
    return map;
  }

  CFFEncoding _readEncoding(
    DataInput input,
    _DictData topDict,
    CFFCharset charset,
  ) {
    final encodingEntry = topDict.getEntry('Encoding');
    final encodingId = encodingEntry != null && encodingEntry.hasOperands
        ? encodingEntry.numbers.first.toInt()
        : 0;

    switch (encodingId) {
      case 0:
        return CFFStandardEncoding.instance;
      case 1:
        return CFFExpertEncoding.instance;
      default:
        input.setPosition(encodingId);
        return _readEmbeddedEncoding(input, charset);
    }
  }

  CFFEncoding _readEmbeddedEncoding(DataInput input, CFFCharset charset) {
    final format = input.readUnsignedByte();
    final baseFormat = format & 0x7F;

    switch (baseFormat) {
      case 0:
        return _readEncodingFormat0(input, charset, format);
      case 1:
        return _readEncodingFormat1(input, charset, format);
      default:
        throw IOException('Unsupported encoding base format $baseFormat');
    }
  }

  CFFEncoding _readEncodingFormat0(
    DataInput input,
    CFFCharset charset,
    int format,
  ) {
    final nCodes = input.readUnsignedByte();
    final encoding = _Format0Encoding(nCodes);
    encoding.addCode(0, 0, '.notdef');
    for (var gid = 1; gid <= nCodes; gid++) {
      final code = input.readUnsignedByte();
      final sid = charset.getSIDForGID(gid);
      encoding.addCode(code, sid, _readString(sid));
    }

    if ((format & 0x80) != 0) {
      _readEncodingSupplement(input, encoding);
    }
    return encoding;
  }

  CFFEncoding _readEncodingFormat1(
    DataInput input,
    CFFCharset charset,
    int format,
  ) {
    final nRanges = input.readUnsignedByte();
    final encoding = _Format1Encoding(nRanges);
    encoding.addCode(0, 0, '.notdef');
    var gid = 1;
    for (var i = 0; i < nRanges; i++) {
      final rangeFirst = input.readUnsignedByte();
      final rangeLeft = input.readUnsignedByte();
      for (var j = 0; j <= rangeLeft; j++) {
        final sid = charset.getSIDForGID(gid++);
        encoding.addCode(rangeFirst + j, sid, _readString(sid));
      }
    }

    if ((format & 0x80) != 0) {
      _readEncodingSupplement(input, encoding);
    }
    return encoding;
  }

  void _readEncodingSupplement(DataInput input, _BuiltInEncoding encoding) {
    final supplements = input.readUnsignedByte();
    for (var i = 0; i < supplements; i++) {
      final code = input.readUnsignedByte();
      final sid = input.readUnsignedShort();
      encoding.addCode(code, sid, _readString(sid));
    }
  }

  CFFCharset _readEmbeddedCharset(DataInput input, int numGlyphs, bool isCid) {
    final format = input.readUnsignedByte();
    switch (format) {
      case 0:
        return _readCharsetFormat0(input, numGlyphs, isCid);
      case 1:
        return _readCharsetFormat1(input, numGlyphs, isCid);
      case 2:
        return _readCharsetFormat2(input, numGlyphs, isCid);
      default:
        throw IOException('Unsupported charset format $format');
    }
  }

  CFFCharset _readCharsetFormat0(DataInput input, int numGlyphs, bool isCid) {
    final charset = _EmbeddedCharset(isCid);
    if (isCid) {
      charset.addCID(0, 0);
      for (var gid = 1; gid < numGlyphs; gid++) {
        charset.addCID(gid, input.readUnsignedShort());
      }
    } else {
      charset.addSID(0, 0, '.notdef');
      for (var gid = 1; gid < numGlyphs; gid++) {
        final sid = input.readUnsignedShort();
        charset.addSID(gid, sid, _readString(sid));
      }
    }
    return charset;
  }

  CFFCharset _readCharsetFormat1(DataInput input, int numGlyphs, bool isCid) {
    final charset = _RangeMappedCharset(isCid);
    if (isCid) {
      charset.addCID(0, 0);
      var gid = 1;
      while (gid < numGlyphs) {
        final first = input.readUnsignedShort();
        final left = input.readUnsignedByte();
        charset.addRangeMapping(_RangeMapping(gid, first, left));
        gid += left + 1;
      }
    } else {
      charset.addSID(0, 0, '.notdef');
      var gid = 1;
      while (gid < numGlyphs) {
        final first = input.readUnsignedShort();
        final left = input.readUnsignedByte() + 1;
        for (var j = 0; j < left; j++) {
          final sid = first + j;
          charset.addSID(gid + j, sid, _readString(sid));
        }
        gid += left;
      }
    }
    return charset;
  }

  CFFCharset _readCharsetFormat2(DataInput input, int numGlyphs, bool isCid) {
    final charset = _RangeMappedCharset(isCid);
    if (isCid) {
      charset.addCID(0, 0);
      var gid = 1;
      while (gid < numGlyphs) {
        final first = input.readUnsignedShort();
        final left = input.readUnsignedShort();
        charset.addRangeMapping(_RangeMapping(gid, first, left));
        gid += left + 1;
      }
    } else {
      charset.addSID(0, 0, '.notdef');
      var gid = 1;
      while (gid < numGlyphs) {
        final first = input.readUnsignedShort();
        final left = input.readUnsignedShort() + 1;
        for (var j = 0; j < left; j++) {
          final sid = first + j;
          charset.addSID(gid + j, sid, _readString(sid));
        }
        gid += left;
      }
    }
    return charset;
  }

  _FdSelect _readFdSelect(DataInput input, int glyphCount) {
    final format = input.readUnsignedByte();
    switch (format) {
      case 0:
        final fds = List<int>.generate(glyphCount, (_) => input.readUnsignedByte());
        return _Format0FDSelect(fds);
      case 3:
        final rangeCount = input.readUnsignedShort();
        final ranges = <_FdRange>[];
        for (var i = 0; i < rangeCount; i++) {
          ranges.add(_FdRange(input.readUnsignedShort(), input.readUnsignedByte()));
        }
        final sentinel = input.readUnsignedShort();
        return _Format3FDSelect(ranges, sentinel);
      default:
        throw IOException('Unsupported FDSelect format $format');
    }
  }

  CFFCIDFont? _parseRos(_DictData topDict) {
    final rosEntry = topDict.getEntry('ROS');
    if (rosEntry == null) {
      return null;
    }
    if (rosEntry.numbers.length < 3) {
      throw IOException('ROS entry must have three operands');
    }

    final cidFont = CFFCIDFont();
    cidFont.registry = _readString(rosEntry.numbers[0].toInt());
    cidFont.ordering = _readString(rosEntry.numbers[1].toInt());
    cidFont.supplement = rosEntry.numbers[2].toInt();
    return cidFont;
  }

  String? _readStringOperand(_DictData dict, String key) {
    final entry = dict.getEntry(key);
    if (entry == null || !entry.hasOperands) {
      return null;
    }
    return _readString(entry.numbers.first.toInt());
  }

  String _readString(int index) {
    if (index < 0) {
      throw IOException('Negative SID $index');
    }
    if (index <= 390) {
      return CFFStandardString.getName(index);
    }
    final offset = index - 391;
    if (offset >= 0 && offset < _stringIndex.length) {
      return _stringIndex[offset];
    }
    return 'SID$index';
  }

  // -- Binary helpers -------------------------------------------------------------------------

  static const String _tagOtto = 'OTTO';
  static const String _tagTtcf = 'ttcf';
  static const String _tagTtfOnly = '\u0000\u0001\u0000\u0000';

  DataInput _createTaggedCffInput(DataInput input) {
    final numTables = input.readUnsignedShort();
    input.readUnsignedShort(); // searchRange
    input.readUnsignedShort(); // entrySelector
    input.readUnsignedShort(); // rangeShift
    for (var i = 0; i < numTables; i++) {
      final tag = _readTagName(input);
      input.readUnsignedShort(); // checksum high
      input.readUnsignedShort();
      final offset = _readLong(input);
      final length = _readLong(input);
      if (tag == 'CFF ') {
        input.setPosition(offset);
        final bytes = input.readBytes(length);
        return DataInputByteArray(bytes);
      }
    }
    throw IOException('CFF table not found in OpenType font');
  }

  static String _readTagName(DataInput input) {
    final bytes = input.readBytes(4);
    return String.fromCharCodes(bytes);
  }

  static int _readLong(DataInput input) {
    final high = input.readUnsignedShort();
    final low = input.readUnsignedShort();
    return (high << 16) | low;
  }

  static _Header _readHeader(DataInput input) {
    final major = input.readUnsignedByte();
    final minor = input.readUnsignedByte();
    final hdrSize = input.readUnsignedByte();
    final offSize = _readOffSize(input);
    final header = _Header(major, minor, hdrSize, offSize);
    if (hdrSize > header.length) {
      final skip = hdrSize - header.length;
      if (skip > 0) {
        input.readBytes(skip);
      }
    }
    return header;
  }

  static int _readOffSize(DataInput input) {
    final offSize = input.readUnsignedByte();
    if (offSize < 1 || offSize > 4) {
      throw IOException('Illegal offSize value $offSize');
    }
    return offSize;
  }

  List<Uint8List> _readIndexData(DataInput input) {
    final offsets = _readIndexOffsets(input);
    if (offsets.isEmpty) {
      return const <Uint8List>[];
    }
    final baseOffset = input.getPosition();
    final result = <Uint8List>[];
    for (var i = 0; i < offsets.length - 1; i++) {
      final start = baseOffset + offsets[i];
      final end = baseOffset + offsets[i + 1];
      input.setPosition(start);
      result.add(input.readBytes(end - start));
    }
    input.setPosition(baseOffset + offsets.last);
    return result;
  }

  List<String> _readStringIndexData(DataInput input) {
    final offsets = _readIndexOffsets(input);
    if (offsets.isEmpty) {
      return const <String>[];
    }
    final baseOffset = input.getPosition();
    final strings = <String>[];
    for (var i = 0; i < offsets.length - 1; i++) {
      final start = baseOffset + offsets[i];
      final end = baseOffset + offsets[i + 1];
      input.setPosition(start);
      final length = end - start;
      strings.add(String.fromCharCodes(input.readBytes(length)));
    }
    input.setPosition(baseOffset + offsets.last);
    return strings;
  }

  List<int> _readIndexOffsets(DataInput input) {
    final count = input.readUnsignedShort();
    if (count == 0) {
      return const <int>[];
    }
    final offSize = _readOffSize(input);
    final offsets = List<int>.generate(count + 1, (_) => input.readOffset(offSize));
    return offsets;
  }

  _DictData _readDictData(DataInput input) {
    final dict = _DictData();
    while (input.hasRemaining()) {
      dict.add(_readEntry(input));
    }
    return dict;
  }

  _DictData _readDictDataRange(DataInput input, int offset, int length) {
    if (length <= 0) {
      return _DictData();
    }
    final dict = _DictData();
    final int endPosition = offset + length;
    final int originalPosition = input.getPosition();
    input.setPosition(offset);
    while (input.getPosition() < endPosition && input.hasRemaining()) {
      dict.add(_readEntry(input));
    }
    input.setPosition(originalPosition);
    return dict;
  }

  _DictEntry _readEntry(DataInput input) {
    final operands = <num>[];
    String? operatorName;

    while (true) {
      final b0 = input.readUnsignedByte();
      if (b0 <= 21) {
        operatorName = _readOperator(b0, input);
        break;
      } else if (b0 == 28 || b0 == 29) {
        operands.add(_readInteger(b0, input));
      } else if (b0 == 30) {
        operands.add(_readRealNumber(input));
      } else if (b0 >= 32 && b0 <= 254) {
        operands.add(_readInteger(b0, input));
      } else {
        throw IOException('Invalid DICT data byte $b0');
      }
    }

    return _DictEntry(operatorName, operands);
  }

  String? _readOperator(int b0, DataInput input) {
    if (b0 == 12) {
      final b1 = input.readUnsignedByte();
      return CffOperator.getOperator(b0, b1);
    }
    return CffOperator.getOperator(b0);
  }

  num _readInteger(int b0, DataInput input) {
    if (b0 == 28) {
      return input.readShort();
    }
    if (b0 == 29) {
      return input.readInt();
    }
    if (b0 >= 32 && b0 <= 246) {
      return b0 - 139;
    }
    if (b0 >= 247 && b0 <= 250) {
      final b1 = input.readUnsignedByte();
      return (b0 - 247) * 256 + b1 + 108;
    }
    if (b0 >= 251 && b0 <= 254) {
      final b1 = input.readUnsignedByte();
      return -(b0 - 251) * 256 - b1 - 108;
    }
    throw IOException('Unsupported integer byte $b0');
  }

  double _readRealNumber(DataInput input) {
    final buffer = StringBuffer();
    var done = false;
    final nibbles = List<int>.filled(2, 0);
    while (!done) {
      final b = input.readUnsignedByte();
      nibbles[0] = b >> 4;
      nibbles[1] = b & 0x0F;
      for (final nibble in nibbles) {
        switch (nibble) {
          case 0x0:
          case 0x1:
          case 0x2:
          case 0x3:
          case 0x4:
          case 0x5:
          case 0x6:
          case 0x7:
          case 0x8:
          case 0x9:
            buffer.write(nibble);
            break;
          case 0xA:
            buffer.write('.');
            break;
          case 0xB:
            buffer.write('E');
            break;
          case 0xC:
            buffer.write('E-');
            break;
          case 0xE:
            buffer.write('-');
            break;
          case 0xF:
            done = true;
            break;
          case 0xD:
            break;
          default:
            throw IOException('Illegal nibble $nibble in real number');
        }
        if (done) {
          break;
        }
      }
    }
    return double.parse(buffer.isEmpty ? '0' : buffer.toString());
  }
}

class _Header {
  const _Header(this.major, this.minor, this.hdrSize, this.offSize);

  final int major;
  final int minor;
  final int hdrSize;
  final int offSize;

  int get length => 4;
}

class _DictData {
  final Map<String, _DictEntry> _entries = <String, _DictEntry>{};

  void add(_DictEntry entry) {
    final op = entry.operatorName;
    if (op != null) {
      _entries[op] = entry;
    }
  }

  _DictEntry? getEntry(String name) => _entries[name];

  bool get isEmpty => _entries.isEmpty;

  bool hasEntry(String name) => _entries.containsKey(name);

  bool? getBoolean(String name, bool defaultValue) {
    final entry = _entries[name];
    if (entry == null || !entry.hasOperands) {
      return defaultValue;
    }
    final value = entry.numbers.first.toInt();
    return value != 0;
  }

  num? getNumber(String name, num? defaultValue) {
    final entry = _entries[name];
    if (entry == null || !entry.hasOperands) {
      return defaultValue;
    }
    return entry.numbers.first;
  }

  List<num>? getArray(String name, List<num>? defaultValue) {
    final entry = _entries[name];
    if (entry == null || !entry.hasOperands) {
      return defaultValue;
    }
    return List<num>.from(entry.numbers);
  }

  List<num>? getDelta(String name) {
    final entry = _entries[name];
    if (entry == null || entry.numbers.isEmpty) {
      return null;
    }
    final result = <num>[];
    var sum = 0;
    for (final value in entry.numbers) {
      sum += value.toInt();
      result.add(sum);
    }
    return result;
  }
}

class _DictEntry {
  _DictEntry(this.operatorName, List<num> operands)
      : numbers = List<num>.unmodifiable(operands);

  final String? operatorName;
  final List<num> numbers;

  bool get hasOperands => numbers.isNotEmpty;
}

class _EmbeddedCharset extends EmbeddedCharset {
  _EmbeddedCharset(bool isCidFont) : super(isCidFont: isCidFont);
}

class _RangeMappedCharset extends _EmbeddedCharset {
  _RangeMappedCharset(bool isCidFont)
      : _ranges = <_RangeMapping>[],
        super(isCidFont);

  final List<_RangeMapping> _ranges;

  void addRangeMapping(_RangeMapping range) {
    _ranges.add(range);
  }

  @override
  int getCIDForGID(int gid) {
    if (isCIDFont) {
      for (final range in _ranges) {
        if (range.containsGid(gid)) {
          return range.cidFromGid(gid);
        }
      }
    }
    return super.getCIDForGID(gid);
  }

  @override
  int getGIDForCID(int cid) {
    if (isCIDFont) {
      for (final range in _ranges) {
        if (range.containsCid(cid)) {
          return range.gidFromCid(cid);
        }
      }
    }
    return super.getGIDForCID(cid);
  }
}

class _RangeMapping {
  _RangeMapping(this.startGid, this.startMappedValue, this.nLeft)
      : endGid = startGid + nLeft,
        endMappedValue = startMappedValue + nLeft;

  final int startGid;
  final int startMappedValue;
  final int nLeft;
  final int endGid;
  final int endMappedValue;

  bool containsGid(int gid) => gid >= startGid && gid <= endGid;

  bool containsCid(int cid) => cid >= startMappedValue && cid <= endMappedValue;

  int cidFromGid(int gid) => startMappedValue + (gid - startGid);

  int gidFromCid(int cid) => startGid + (cid - startMappedValue);
}

abstract class _FdSelect implements CFFFDSelect {}

class _Format0FDSelect extends _FdSelect {
  _Format0FDSelect(this.fds);

  final List<int> fds;

  @override
  int getFDIndex(int gid) => gid < fds.length ? fds[gid] : 0;
}

class _Format3FDSelect extends _FdSelect {
  _Format3FDSelect(this.ranges, this.sentinel);

  final List<_FdRange> ranges;
  final int sentinel;

  @override
  int getFDIndex(int gid) {
    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final nextFirst = i + 1 < ranges.length ? ranges[i + 1].first : sentinel;
      if (gid >= range.first && gid < nextFirst) {
        return range.fd;
      }
    }
    return 0;
  }
}

class _FdRange {
  const _FdRange(this.first, this.fd);

  final int first;
  final int fd;
}

class _BuiltInEncoding extends CFFEncoding {
  void addCode(int code, int sid, String name) {
    addCharacterEncoding(code, name);
  }
}

class _Format0Encoding extends _BuiltInEncoding {
  _Format0Encoding(this.nCodes);

  final int nCodes;
}

class _Format1Encoding extends _BuiltInEncoding {
  _Format1Encoding(this.nRanges);

  final int nRanges;
}

class _EmptyCharsetType1 extends EmbeddedCharset {
  _EmptyCharsetType1() : super(isCidFont: false) {
    addSID(0, 0, '.notdef');
  }
}

class _EmptyCharsetCID extends EmbeddedCharset {
  _EmptyCharsetCID(int numCharStrings) : super(isCidFont: true) {
    addCID(0, 0);
    for (var i = 1; i <= numCharStrings; i++) {
      addCID(i, i);
    }
  }
}

class _InMemoryByteSource implements CFFByteSource {
  _InMemoryByteSource(this.bytes);

  final Uint8List bytes;

  @override
  Uint8List getBytes() => Uint8List.fromList(bytes);
}

import 'dart:convert';
import 'dart:typed_data';

import '../io/ttf_data_stream.dart';
import 'font_headers.dart';
import 'name_record.dart';
import 'ttf_table.dart';

/// Required 'name' table containing localized font metadata.
class NamingTable extends TtfTable {
  static const String tableTag = 'name';

  List<NameRecord> _nameRecords = const <NameRecord>[];
  final Map<int, Map<int, Map<int, Map<int, String?>>>> _lookupTable =
      <int, Map<int, Map<int, Map<int, String?>>>>{};

  List<String> _languageTags = const <String>[];
  Map<String, int> _languageTagLookup = const <String, int>{};

  String? _fontFamily;
  String? _fontSubFamily;
  String? _postScriptName;

  static const int _languageTagBase = 0x8000;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    _readInternal(ttf, data, onlyHeaders: false);
    setInitialized(true);
  }

  @override
  void readHeaders(dynamic ttf, TtfDataStream data, FontHeaders outHeaders) {
    _readInternal(ttf, data, onlyHeaders: true);
    outHeaders.setName(_postScriptName);
    outHeaders.setFontFamily(_fontFamily, _fontSubFamily);
  }

  String? getFontFamily() => _fontFamily;

  String? getFontSubFamily() => _fontSubFamily;

  String? getPostScriptName() => _postScriptName;

  List<NameRecord> getNameRecords() =>
      List<NameRecord>.unmodifiable(_nameRecords);

  List<String> get languageTags => List<String>.unmodifiable(_languageTags);

  String? getName(int nameId, int platformId, int encodingId, int languageId) {
    final platforms = _lookupTable[nameId];
    if (platforms == null) {
      return null;
    }
    final encodings = platforms[platformId];
    if (encodings == null) {
      return null;
    }
    final languages = encodings[encodingId];
    if (languages == null) {
      return null;
    }
    return languages[languageId];
  }

  void _readInternal(dynamic ttf, TtfDataStream data,
      {required bool onlyHeaders}) {
    final formatSelector = data.readUnsignedShort();
    final bool useLongOffsets = formatSelector == 3;
    if (formatSelector != 0 && formatSelector != 1 && formatSelector != 3) {
      throw UnsupportedError(
          'Naming table format $formatSelector not yet supported');
    }
    final numberOfNameRecords = data.readUnsignedShort();
    final int storageOffset =
        useLongOffsets ? data.readUnsignedInt() : data.readUnsignedShort();

    final records =
        List<NameRecord>.generate(numberOfNameRecords, (_) => NameRecord());
    for (final record in records) {
      record.readData(data, useLongOffsets: useLongOffsets);
    }
    final bool hasLanguageTags = formatSelector == 1 || formatSelector == 3;
    final List<_LangTagRecord> langTagRecords;
    if (hasLanguageTags) {
      final count = data.readUnsignedShort();
      langTagRecords = List<_LangTagRecord>.generate(count, (_) {
        final length =
            useLongOffsets ? data.readUnsignedInt() : data.readUnsignedShort();
        final offsetValue =
            useLongOffsets ? data.readUnsignedInt() : data.readUnsignedShort();
        return _LangTagRecord(length, offsetValue);
      });
    } else {
      langTagRecords = const <_LangTagRecord>[];
    }

    final filtered = <NameRecord>[];
    for (final record in records) {
      if (!onlyHeaders || _isRelevantForHeaders(record)) {
        filtered.add(record);
      }
    }
    _nameRecords = filtered;

    for (final record in _nameRecords) {
      if (storageOffset + record.stringOffset > length) {
        record.string = null;
        continue;
      }
      final absoluteOffset = offset + storageOffset + record.stringOffset;
      final available = offset + length - absoluteOffset;
      if (record.stringLength > available) {
        record.string = null;
        continue;
      }
      data.seek(absoluteOffset);
      record.string = _readString(data, record);
    }

    if (langTagRecords.isEmpty) {
      _languageTags = const <String>[];
      _languageTagLookup = const <String, int>{};
    } else {
      final tags = <String>[];
      final lookup = <String, int>{};
      for (final tag in langTagRecords) {
        if (storageOffset + tag.offset >= length || tag.length <= 0) {
          tags.add('');
          continue;
        }
        final absoluteOffset = offset + storageOffset + tag.offset;
        final available = offset + length - absoluteOffset;
        if (tag.length > available) {
          tags.add('');
          continue;
        }
        data.seek(absoluteOffset);
        final bytes = data.readBytes(tag.length);
        tags.add(_decodeUtf16(bytes, Endian.big));
      }
      _languageTags = List<String>.unmodifiable(tags);
      for (var i = 0; i < tags.length; i++) {
        final normalized = _normalizeLanguageTag(tags[i]);
        if (normalized.isEmpty) {
          continue;
        }
        lookup.putIfAbsent(normalized, () => _languageTagBase + i);
      }
      _languageTagLookup = Map<String, int>.unmodifiable(lookup);
    }

    _lookupTable.clear();
    for (final record in _nameRecords) {
      final platformLookup = _lookupTable.putIfAbsent(
          record.nameId, () => <int, Map<int, Map<int, String?>>>{});
      final encodingLookup = platformLookup.putIfAbsent(
          record.platformId, () => <int, Map<int, String?>>{});
      final languageLookup = encodingLookup.putIfAbsent(
          record.platformEncodingId, () => <int, String?>{});
      languageLookup[record.languageId] = record.string;
    }

    _fontFamily = _getEnglishName(NameRecord.nameFontFamilyName);
    _fontSubFamily = _getEnglishName(NameRecord.nameFontSubFamilyName);
    _postScriptName = _getNameFallback(NameRecord.namePostScriptName);
    if (_postScriptName != null) {
      _postScriptName = _postScriptName!.trim();
    }
  }

  String? getNameByLanguageTag(
      int nameId, int platformId, int encodingId, String languageTag) {
    final lookup = _languageTagLookup;
    if (lookup.isEmpty) {
      return null;
    }
    final normalized = _normalizeLanguageTag(languageTag);
    if (normalized.isEmpty) {
      return null;
    }
    final languageId = lookup[normalized];
    if (languageId == null) {
      return null;
    }
    return getName(nameId, platformId, encodingId, languageId);
  }

  bool _isRelevantForHeaders(NameRecord record) {
    switch (record.nameId) {
      case NameRecord.namePostScriptName:
      case NameRecord.nameFontFamilyName:
      case NameRecord.nameFontSubFamilyName:
        return record.languageId == NameRecord.languageUnicode ||
            record.languageId == NameRecord.languageWindowsEnUs;
      default:
        return false;
    }
  }

  String? _getEnglishName(int nameId) {
    for (var encodingId = NameRecord.encodingUnicode20Full;
        encodingId >= NameRecord.encodingUnicode10;
        encodingId--) {
      final value = getName(nameId, NameRecord.platformUnicode, encodingId,
          NameRecord.languageUnicode);
      if (value != null) {
        return value;
      }
    }
    final windows = getName(
      nameId,
      NameRecord.platformWindows,
      NameRecord.encodingWindowsUnicodeBmp,
      NameRecord.languageWindowsEnUs,
    );
    if (windows != null) {
      return windows;
    }
    return getName(
      nameId,
      NameRecord.platformMacintosh,
      NameRecord.encodingMacintoshRoman,
      NameRecord.languageMacintoshEnglish,
    );
  }

  String? _getNameFallback(int nameId) {
    final mac = getName(
      nameId,
      NameRecord.platformMacintosh,
      NameRecord.encodingMacintoshRoman,
      NameRecord.languageMacintoshEnglish,
    );
    if (mac != null) {
      return mac;
    }
    return getName(
      nameId,
      NameRecord.platformWindows,
      NameRecord.encodingWindowsUnicodeBmp,
      NameRecord.languageWindowsEnUs,
    );
  }

  String? _readString(TtfDataStream data, NameRecord record) {
    final bytes = data.readBytes(record.stringLength);
    switch (record.platformId) {
      case NameRecord.platformWindows:
        if (record.platformEncodingId == NameRecord.encodingWindowsSymbol ||
            record.platformEncodingId == NameRecord.encodingWindowsUnicodeBmp) {
          return _decodeUtf16(bytes, Endian.big);
        }
        return latin1.decode(bytes, allowInvalid: true);
      case NameRecord.platformUnicode:
        return _decodeUtf16(bytes, Endian.big);
      case NameRecord.platformIso:
        if (record.platformEncodingId == 0) {
          return ascii.decode(bytes, allowInvalid: true);
        }
        if (record.platformEncodingId == 1) {
          return _decodeUtf16(bytes, Endian.big);
        }
        return latin1.decode(bytes, allowInvalid: true);
      case NameRecord.platformMacintosh:
        return latin1.decode(bytes, allowInvalid: true);
      default:
        return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _decodeUtf16(Uint8List bytes, Endian endian) {
    if (bytes.isEmpty) {
      return '';
    }
    final view = ByteData.sublistView(bytes);
    final codeUnits = List<int>.filled(bytes.length ~/ 2, 0);
    for (var i = 0; i < codeUnits.length; i++) {
      codeUnits[i] = view.getUint16(i * 2, endian);
    }
    return String.fromCharCodes(codeUnits);
  }

  static String _normalizeLanguageTag(String value) => value.trim().toLowerCase();
}

class _LangTagRecord {
  const _LangTagRecord(this.length, this.offset);

  final int length;
  final int offset;
}

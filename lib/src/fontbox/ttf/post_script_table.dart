import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';

import '../io/ttf_data_stream.dart';
import 'cmap_table.dart' show HasGlyphCount;
import 'ttf_table.dart';
import 'wgl4_names.dart';

/// TrueType 'post' table containing PostScript-specific metrics and glyph names.
class PostScriptTable extends TtfTable {
  static const String tableTag = 'post';
  static final Logger _log = Logger('fontbox.PostScriptTable');

  double _formatType = 0;
  double _italicAngle = 0;
  int _underlinePosition = 0;
  int _underlineThickness = 0;
  int _isFixedPitch = 0;
  int _minMemType42 = 0;
  int _maxMemType42 = 0;
  int _minMemType1 = 0;
  int _maxMemType1 = 0;
  List<String>? _glyphNames;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    _formatType = data.read32Fixed();
    _italicAngle = data.read32Fixed();
    _underlinePosition = data.readSignedShort();
    _underlineThickness = data.readSignedShort();
    _isFixedPitch = data.readUnsignedInt();
    _minMemType42 = data.readUnsignedInt();
    _maxMemType42 = data.readUnsignedInt();
    _minMemType1 = data.readUnsignedInt();
    _maxMemType1 = data.readUnsignedInt();

    if (_formatType == 1.0) {
      _glyphNames = Wgl4Names.getAllNames();
    } else if (_formatType == 2.0) {
      _readFormat2(ttf, data);
    } else if (_formatType == 2.5) {
      _readFormat2Point5(ttf, data);
    } else if (_formatType == 3.0) {
      _log.fine('No PostScript name information is provided for the font');
    } else if (data.currentPosition == data.originalDataSize) {
      _log.warning('No PostScript name data is provided for the font');
    }

    setInitialized(true);
  }

  void _readFormat2(dynamic ttf, TtfDataStream data) {
    final numGlyphs = data.readUnsignedShort();
    final glyphNameIndex = List<int>.filled(numGlyphs, 0);
    var maxIndex = -0x7fffffff;

    for (var i = 0; i < numGlyphs; ++i) {
      final index = data.readUnsignedShort();
      glyphNameIndex[i] = index;
      if (index <= 32767) {
        if (index > maxIndex) {
          maxIndex = index;
        }
      }
    }

    List<String>? nameArray;
    if (maxIndex >= Wgl4Names.numberOfMacGlyphs) {
      final customCount = maxIndex - Wgl4Names.numberOfMacGlyphs + 1;
      nameArray = List<String>.filled(customCount, '', growable: false);
      for (var i = 0; i < customCount; ++i) {
        final len = data.readUnsignedByte();
        try {
          nameArray[i] = data.readString(len);
        } on IOException catch (e) {
          _log.warning(
            'Error reading names in PostScript table at entry $i of $customCount, setting remaining entries to .notdef',
            e,
          );
          for (var j = i; j < customCount; ++j) {
            nameArray[j] = '.notdef';
          }
          break;
        }
      }
    }

    final resolved =
        List<String>.filled(numGlyphs, '.undefined', growable: false);
    for (var i = 0; i < numGlyphs; ++i) {
      final index = glyphNameIndex[i];
      if (index >= 0 && index < Wgl4Names.numberOfMacGlyphs) {
        final name = Wgl4Names.getGlyphName(index);
        if (name != null) {
          resolved[i] = name;
        }
      } else if (index >= Wgl4Names.numberOfMacGlyphs &&
          index <= 32767 &&
          nameArray != null) {
        final localIndex = index - Wgl4Names.numberOfMacGlyphs;
        if (localIndex >= 0 && localIndex < nameArray.length) {
          resolved[i] = nameArray[localIndex];
        }
      } else {
        resolved[i] = '.undefined';
      }
    }

    _glyphNames = resolved;
  }

  void _readFormat2Point5(dynamic ttf, TtfDataStream data) {
    final glyphCount = ttf is HasGlyphCount ? ttf.numberOfGlyphs : 0;
    final glyphNameIndex = List<int>.filled(glyphCount, 0);
    for (var i = 0; i < glyphCount; ++i) {
      final offset = data.readSignedByte();
      glyphNameIndex[i] = i + 1 + offset;
    }

    final names = List<String>.filled(glyphCount, '.notdef', growable: false);
    for (var i = 0; i < glyphCount; ++i) {
      final index = glyphNameIndex[i];
      if (index >= 0 && index < Wgl4Names.numberOfMacGlyphs) {
        final name = Wgl4Names.getGlyphName(index);
        if (name != null) {
          names[i] = name;
        }
      } else {
        _log.fine(
            'incorrect glyph name index $index, valid numbers 0..${Wgl4Names.numberOfMacGlyphs - 1}');
      }
    }

    _glyphNames = names;
  }

  double get formatType => _formatType;
  double get italicAngle => _italicAngle;
  int get underlinePosition => _underlinePosition;
  int get underlineThickness => _underlineThickness;
  int get isFixedPitch => _isFixedPitch;
  int get minMemType42 => _minMemType42;
  int get maxMemType42 => _maxMemType42;
  int get minMemType1 => _minMemType1;
  int get maxMemType1 => _maxMemType1;
  List<String>? get glyphNames =>
      _glyphNames == null ? null : List<String>.from(_glyphNames!);

  String? getName(int gid) {
    final names = _glyphNames;
    if (names == null || gid < 0 || gid >= names.length) {
      return null;
    }
    return names[gid];
  }
}

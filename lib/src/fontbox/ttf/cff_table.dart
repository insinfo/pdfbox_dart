import 'dart:typed_data' as typed;

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../cff/cff_font.dart';
import '../cff/cff_parser.dart';
import '../io/ttf_data_stream.dart';
import 'font_headers.dart';
import 'true_type_font.dart';
import 'ttf_table.dart';

/// Compact Font Format (CFF) table containing PostScript outlines.
class CffTable extends TtfTable {
  static const String tableTag = 'CFF ';
  static final Logger _log = Logger('fontbox.CffTable');

  typed.Uint8List? _rawData;
  List<CFFFont> _fonts = <CFFFont>[];

  /// Returns an immutable view of the raw CFF data, if this table has been
  /// initialised.
  typed.Uint8List get rawData {
    final data = _rawData;
    if (data == null) {
      throw StateError('CFF table has not been read');
    }
    return typed.Uint8List.fromList(data);
  }

  /// Whether the raw CFF bytes are available.
  bool get hasData => _rawData != null;

  /// Returns the primary CFF font stored inside this table.
  CFFFont get font {
    if (_fonts.isEmpty) {
      throw StateError('CFF table has not been read');
    }
    return _fonts.first;
  }

  /// Returns all CFF fonts described in the table.
  List<CFFFont> get fonts => List<CFFFont>.unmodifiable(_fonts);

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final bytes = data.readBytes(length);
    _rawData = typed.Uint8List.fromList(bytes);

    final parser = CffParser();
    CFFByteSource? byteSource;
    if (ttf is TrueTypeFont) {
      byteSource = _TrueTypeFontByteSource(ttf);
    }
    try {
      final parsedFonts = parser.parse(bytes, byteSource: byteSource);
      if (parsedFonts.isEmpty) {
        throw StateError('CFF table does not contain any fonts');
      }
      _fonts = parsedFonts;
    } on IOException catch (error, stackTrace) {
      _log.warning('Failed to parse CFF table, retaining raw bytes only', error, stackTrace);
      _fonts = <CFFFont>[];
    }
    setInitialized(true);
  }

  @override
  void readHeaders(dynamic ttf, TtfDataStream data, FontHeaders outHeaders) {
    final parser = CffParser();
    RandomAccessRead? view;
    try {
      view = data.createSubView(length);
      if (view != null) {
        parser.parseFirstSubFontRos(view, outHeaders);
        return;
      }
    } finally {
      view?.close();
    }

    final bytes = data.readBytes(length);
    final buffer = RandomAccessReadBuffer.fromBytes(bytes);
    try {
      parser.parseFirstSubFontRos(buffer, outHeaders);
    } finally {
      buffer.close();
    }
  }
}

class _TrueTypeFontByteSource implements CFFByteSource {
  _TrueTypeFontByteSource(this.ttf);

  final TrueTypeFont ttf;

  @override
  typed.Uint8List getBytes() {
    final table = ttf.tableMap[CffTable.tableTag];
    if (table is! CffTable) {
      throw StateError('CFF table has not been initialised');
    }
    return typed.Uint8List.fromList(ttf.getTableBytes(table));
  }
}

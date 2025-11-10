import 'dart:io';

import 'package:logging/logging.dart';

import '../../../fontbox/font_box_font.dart';
import '../../../fontbox/ttf/open_type_font.dart';
import '../../../fontbox/ttf/os2_windows_metrics_table.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import '../../../fontbox/ttf/ttf_parser.dart';
import '../../../io/random_access_read_buffered_file.dart';
import 'cid_system_info.dart';
import 'font_cache.dart';
import 'font_format.dart';
import 'font_info.dart';
import 'pd_panose.dart';
import 'pd_panose_classification.dart';
import 'true_type_font_box_adapter.dart';

/// Metadata for a font discovered on the local file system.
class FileSystemFontInfo extends FontInfo {
  FileSystemFontInfo({
    required this.path,
    required FontFormat format,
    required FontCache cache,
    Logger? logger,
  })  : _format = format,
        _cache = cache,
        _logger = logger ?? Logger('pdfbox.FileSystemFontInfo') {
    _postScriptName = _deriveFileName();
    _initialiseMetadata();
  }

  final String path;
  final FontFormat _format;
  final FontCache _cache;
  final Logger _logger;

  String _postScriptName = '';
  int _familyClass = -1;
  int _weightClass = -1;
  int _codePageRange1 = 0;
  int _codePageRange2 = 0;
  int _macStyle = -1;
  PDPanoseClassification? _panose;
  CidSystemInfo? _cidSystemInfo;

  String _deriveFileName() => File(path).uri.pathSegments.isEmpty
      ? path
      : File(path).uri.pathSegments.last;

  void _initialiseMetadata() {
    switch (_format) {
      case FontFormat.ttf:
      case FontFormat.otf:
        _readTrueTypeMetadata();
        break;
      case FontFormat.pfb:
        // TODO: add Type 1 metadata extraction when Type 1 support lands.
        break;
    }
  }

  void _readTrueTypeMetadata() {
    RandomAccessReadBufferedFile? randomAccess;
    try {
      randomAccess = RandomAccessReadBufferedFile(path);
      final parser = TtfParser();
      final headers = parser.parseTableHeaders(randomAccess);
      _postScriptName = headers.name ?? _postScriptName;
      _macStyle = headers.headerMacStyle ?? -1;

      if (headers.otfRegistry != null && headers.otfOrdering != null) {
        _cidSystemInfo = CidSystemInfo(
          registry: headers.otfRegistry!,
          ordering: headers.otfOrdering!,
          supplement: headers.otfSupplement,
        );
      }

      final os2 = headers.os2Windows as Os2WindowsMetricsTable?;
      if (os2 != null) {
        _familyClass = os2.familyClass;
        _weightClass = os2.weightClass;
        _codePageRange1 = os2.codePageRange1;
        _codePageRange2 = os2.codePageRange2;
        if (os2.panose.isNotEmpty) {
          try {
            _panose = PDPanose(os2.panose).panose;
          } on AssertionError catch (error, stackTrace) {
            _logger.fine('Invalid Panose data for $_postScriptName', error, stackTrace);
          }
        }
      }
    } catch (error, stackTrace) {
      _logger.warning('Failed to read metadata for font at $path', error, stackTrace);
    } finally {
      randomAccess?.close();
    }
  }

  /// Lazily loads the underlying TrueType font program.
  TrueTypeFont loadTrueTypeFont() {
    final parser = TtfParser();
    final randomAccess = RandomAccessReadBufferedFile(path);
    return parser.parse(randomAccess);
  }

  /// Loads the font and casts to [OpenTypeFont] when applicable.
  OpenTypeFont? loadOpenTypeFont() {
    final font = loadTrueTypeFont();
    return font is OpenTypeFont ? font : null;
  }

  @override
  String get postScriptName => _postScriptName;

  @override
  FontFormat get format => _format;

  @override
  CidSystemInfo? get cidSystemInfo => _cidSystemInfo;

  @override
  FontBoxFont getFont() {
    final cached = _cache.getFont(this);
    if (cached != null) {
      return cached;
    }
    final trueType = loadTrueTypeFont();
    final adapter = TrueTypeFontBoxAdapter(trueType);
    _cache.addFont(this, adapter);
    return adapter;
  }

  @override
  int get familyClass => _familyClass;

  @override
  int get weightClass => _weightClass;

  @override
  int get codePageRange1 => _codePageRange1;

  @override
  int get codePageRange2 => _codePageRange2;

  @override
  int get macStyle => _macStyle;

  @override
  PDPanoseClassification? get panose => _panose;
}

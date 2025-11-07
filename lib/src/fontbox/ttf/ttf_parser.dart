import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/io_utils.dart';
import '../../io/random_access_read.dart';
import '../io/random_access_read_data_stream.dart';
import '../io/random_access_read_unbuffered_data_stream.dart';
import '../io/ttf_data_stream.dart';
import 'cff_table.dart';
import 'cmap_table.dart';
import 'digital_signature_table.dart';
import 'font_headers.dart';
import 'glyph_substitution_table.dart';
import 'glyph_table.dart';
import 'header_table.dart';
import 'horizontal_header_table.dart';
import 'horizontal_metrics_table.dart';
import 'index_to_location_table.dart';
import 'kerning_table.dart';
import 'maximum_profile_table.dart';
import 'naming_table.dart';
import 'open_type_font.dart';
import 'os2_windows_metrics_table.dart';
import 'post_script_table.dart';
import 'true_type_font.dart';
import 'ttf_table.dart';
import 'vertical_header_table.dart';
import 'vertical_metrics_table.dart';
import 'vertical_origin_table.dart';

/// Parser for TrueType and OpenType font files.
class TtfParser {
  TtfParser({bool isEmbedded = false}) : _isEmbedded = isEmbedded;

  static final Logger _log = Logger('fontbox.TtfParser');

  bool _isEmbedded;

  /// Parses font data from a [RandomAccessRead]. The returned [TrueTypeFont]
  /// owns the underlying data stream and must be closed by the caller when no
  /// longer needed.
  TrueTypeFont parse(RandomAccessRead randomAccessRead) {
    final dataStream =
        RandomAccessReadDataStream.fromRandomAccessRead(randomAccessRead);
    IOUtils.closeQuietly(randomAccessRead);
    try {
      return parseDataStream(dataStream);
    } catch (_) {
      dataStream.close();
      rethrow;
    }
  }

  /// Parses font data from an existing [TtfDataStream]. Ownership of the stream
  /// is transferred to the returned font instance.
  TrueTypeFont parseDataStream(TtfDataStream dataStream) {
    final font = _createFontWithTables(dataStream);
    _parseTables(font);
    return font;
  }

  /// Parses only the table headers of a font, avoiding full table decoding.
  FontHeaders parseTableHeaders(RandomAccessRead randomAccessRead) {
    final stream = RandomAccessReadUnbufferedDataStream(randomAccessRead);
    try {
      return parseTableHeadersFromDataStream(stream);
    } finally {
      stream.close();
    }
  }

  FontHeaders parseTableHeadersFromDataStream(TtfDataStream dataStream) {
    final font = _createFontWithTables(dataStream);
    try {
      final headers = FontHeaders();
      font.readTableHeaders(NamingTable.tableTag, headers);
      font.readTableHeaders(HeaderTable.tableTag, headers);
      headers.setOs2Windows(font.getOs2WindowsMetricsTable());
      headers.setIsOtfAndPostScript(font is OpenTypeFont && font.isPostScript);
      return headers;
    } finally {
      font.close();
    }
  }

  TrueTypeFont newFont(TtfDataStream dataStream) =>
      TrueTypeFont.fromDataStream(dataStream);

  TrueTypeFont _createFontWithTables(TtfDataStream dataStream) {
    final font = newFont(dataStream);
    final rawVersion = dataStream.readUnsignedInt();
    font.setVersion(_fromFixed32(rawVersion));
    if (font is OpenTypeFont) {
      font.setRawVersion(rawVersion);
    }
    final numberOfTables = dataStream.readUnsignedShort();
    dataStream.readUnsignedShort(); // searchRange
    dataStream.readUnsignedShort(); // entrySelector
    dataStream.readUnsignedShort(); // rangeShift
    for (var i = 0; i < numberOfTables; i++) {
      final table = _readTableDirectory(dataStream);
      if (table == null) {
        continue;
      }
      final endOffset = table.offset + table.length;
      final dataSize = font.originalDataSize;
      if (dataSize > 0 && endOffset > dataSize) {
        _log.warning(
          "Skip table '${table.tag}' which exceeds the font size; offset: ${table.offset}, "
          'length: ${table.length}, fontSize: $dataSize',
        );
        continue;
      }
      font.addTable(table);
    }
    return font;
  }

  void _parseTables(TrueTypeFont font) {
    for (final table in font.tables) {
      if (!table.initialized) {
        font.readTable(table);
      }
    }

    final hasCff = font.tableMap.containsKey(CffTable.tableTag);
    final isOtf = font is OpenTypeFont;
    final isPostScript = isOtf ? font.isPostScript : hasCff;

    final head = font.getHeaderTable();
    if (head == null) {
      throw IOException("'head' table is mandatory");
    }

    final hhea = font.getHorizontalHeaderTable();
    if (hhea == null) {
      throw IOException("'hhea' table is mandatory");
    }

    final maxp = font.getMaximumProfileTable();
    if (maxp == null) {
      throw IOException("'maxp' table is mandatory");
    }

    final post = font.getPostScriptTable();
    if (post == null && !_isEmbedded) {
      throw IOException("'post' table is mandatory");
    }

    if (!isPostScript) {
      if (font.getIndexToLocationTable() == null) {
        throw IOException("'loca' table is mandatory");
      }
      if (font.getGlyphTable() == null) {
        throw IOException("'glyf' table is mandatory");
      }
    } else if (!isOtf) {
      throw IOException('TrueType fonts using CFF outlines are not supported');
    }

    if (font.getNamingTable() == null && !_isEmbedded) {
      throw IOException("'name' table is mandatory");
    }

    if (font.getHorizontalMetricsTable() == null) {
      throw IOException("'hmtx' table is mandatory");
    }

    if (!_isEmbedded && font.getCmapTable() == null) {
      throw IOException("'cmap' table is mandatory");
    }
  }

  TtfTable? _readTableDirectory(TtfDataStream dataStream) {
    final tag = dataStream.readTag();
    TtfTable table;
    switch (tag) {
      case CmapTable.tableTag:
        table = CmapTable();
        break;
      case GlyphTable.tableTag:
        table = GlyphTable();
        break;
      case HeaderTable.tableTag:
        table = HeaderTable();
        break;
      case HorizontalHeaderTable.tableTag:
        table = HorizontalHeaderTable();
        break;
      case HorizontalMetricsTable.tableTag:
        table = HorizontalMetricsTable();
        break;
      case IndexToLocationTable.tableTag:
        table = IndexToLocationTable();
        break;
      case MaximumProfileTable.tableTag:
        table = MaximumProfileTable();
        break;
      case NamingTable.tableTag:
        table = NamingTable();
        break;
      case Os2WindowsMetricsTable.tableTag:
        table = Os2WindowsMetricsTable();
        break;
      case PostScriptTable.tableTag:
        table = PostScriptTable();
        break;
      case DigitalSignatureTable.tableTag:
        table = DigitalSignatureTable();
        break;
      case KerningTable.tableTag:
        table = KerningTable();
        break;
      case VerticalHeaderTable.tableTag:
        table = VerticalHeaderTable();
        break;
      case VerticalMetricsTable.tableTag:
        table = VerticalMetricsTable();
        break;
      case VerticalOriginTable.tableTag:
        table = VerticalOriginTable();
        break;
      case GlyphSubstitutionTable.tableTag:
        table = GlyphSubstitutionTable();
        break;
      case CffTable.tableTag:
        if (!allowCff()) {
          table = TtfTable();
        } else {
          table = CffTable();
        }
        break;
      default:
        table = readTable(tag);
        break;
    }

    table.setTag(tag);
    table.setCheckSum(dataStream.readUnsignedInt());
    table.setOffset(dataStream.readUnsignedInt());
    table.setLength(dataStream.readUnsignedInt());

    if (table.length == 0 && tag != GlyphTable.tableTag) {
      return null;
    }
    return table;
  }

  /// Hook for subclasses (e.g. [OtfParser]) to return specialised table
  /// implementations.
  TtfTable readTable(String tag) => TtfTable();

  /// Whether the parser accepts CFF-based outlines.
  bool allowCff() => false;

  double _fromFixed32(int rawValue) {
    final intPart = (rawValue >> 16) & 0xffff;
    final fracPart = rawValue & 0xffff;
    return intPart + (fracPart / 65536.0);
  }
}

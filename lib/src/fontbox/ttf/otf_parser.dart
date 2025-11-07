import '../../io/random_access_read.dart';
import '../io/ttf_data_stream.dart';
import 'otl_table.dart';
import 'open_type_font.dart';
import 'ttf_parser.dart';
import 'ttf_table.dart';

/// Parser for OpenType fonts that rely on CFF glyph data.
class OtfParser extends TtfParser {
  OtfParser({bool isEmbedded = false}) : super(isEmbedded: isEmbedded);

  @override
  OpenTypeFont parse(RandomAccessRead randomAccessRead) =>
      super.parse(randomAccessRead) as OpenTypeFont;

  @override
  OpenTypeFont parseDataStream(TtfDataStream dataStream) =>
      super.parseDataStream(dataStream) as OpenTypeFont;

  @override
  OpenTypeFont newFont(TtfDataStream dataStream) => OpenTypeFont(dataStream);

  @override
  TtfTable readTable(String tag) {
    switch (tag) {
      case OtlTable.tableTag:
        return OtlTable();
      default:
        return super.readTable(tag);
    }
  }

  @override
  bool allowCff() => true;
}

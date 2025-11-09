import '../../../io/ttf_data_stream.dart';
import 'value_record.dart';

/// Represents positioning adjustments for a glyph pair in PairPos lookups.
class PairValueRecord {
  PairValueRecord(this.secondGlyph, this.valueRecord1, this.valueRecord2);

  factory PairValueRecord.read(
    TtfDataStream data,
    int valueFormat1,
    int valueFormat2,
  ) {
    final secondGlyph = data.readUnsignedShort();
    final value1 = ValueRecord.read(data, valueFormat1);
    final value2 = ValueRecord.read(data, valueFormat2);
    return PairValueRecord(secondGlyph, value1, value2);
  }

  final int secondGlyph;
  final ValueRecord valueRecord1;
  final ValueRecord valueRecord2;
}

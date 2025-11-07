import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/kerning_table.dart';
import 'package:test/test.dart';

void main() {
  test('reads kerning pair from format 0 subtable', () {
    final bytes = BytesBuilder()
      ..add(_ushort(0)) // table version
      ..add(_ushort(1)) // num subtables
      ..add(_ushort(0)) // subtable version
      ..add(_ushort(20)) // length
      ..add(_ushort(1)) // coverage: horizontal, format 0
      ..add(_ushort(1)) // numPairs
      ..add(_ushort(6)) // searchRange
      ..add(_ushort(0)) // entrySelector
      ..add(_ushort(0)) // rangeShift
      ..add(_ushort(65)) // left glyph
      ..add(_ushort(66)) // right glyph
      ..add(_short(-50)); // value

    final data = Uint8List.fromList(bytes.takeBytes());
    final stream = RandomAccessReadDataStream.fromData(data);

    final table = KerningTable()
      ..setTag(KerningTable.tableTag)
      ..setLength(data.length);
    table.read(null, stream);

    final subtable = table.getHorizontalKerningSubtable();
    expect(subtable, isNotNull);
    expect(subtable!.isHorizontalKerning(), isTrue);

    final kerningValue = subtable.getPairKerning(65, 66);
    expect(kerningValue, -50);

    final sequence = <int>[65, -1, 66, 70];
    final adjustments = subtable.getKerning(sequence);
    expect(adjustments[0], -50);
    expect(adjustments[1], 0);
    expect(adjustments[2], 0);
    expect(adjustments[3], 0);
  });
}

List<int> _ushort(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

List<int> _short(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

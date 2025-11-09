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

  test('reads class-based kerning from format 2 subtable', () {
    final subtable = BytesBuilder()
      ..add(_ushort(0)) // subtable version
      ..add(_ushort(0x0024)) // length
      ..add(_ushort(0x0201)) // coverage: horizontal + format 2
      ..add(_ushort(0x0004)) // rowWidth (2 classes -> 4 bytes)
      ..add(_ushort(0x000E)) // leftClassOffset
      ..add(_ushort(0x0016)) // rightClassOffset
      ..add(_ushort(0x001E)) // arrayOffset
      // left class table at offset 0x000E
      ..add(_ushort(10)) // firstGlyph
      ..add(_ushort(2)) // glyphCount
      ..add(_ushort(0)) // class for glyph 10
      ..add(_ushort(1)) // class for glyph 11
      // right class table at offset 0x0016
      ..add(_ushort(5)) // firstGlyph
      ..add(_ushort(2)) // glyphCount
      ..add(_ushort(0)) // class for glyph 5
      ..add(_ushort(1)) // class for glyph 6
      // kerning array at offset 0x001E (2 rows x 2 columns)
      ..add(_short(0))
      ..add(_short(-20))
      ..add(_short(0))
      ..add(_short(20));

    final bytes = BytesBuilder()
      ..add(_ushort(0)) // table version
      ..add(_ushort(1)) // num subtables
      ..add(subtable.takeBytes());

    final data = Uint8List.fromList(bytes.takeBytes());
    final stream = RandomAccessReadDataStream.fromData(data);

    final table = KerningTable()
      ..setTag(KerningTable.tableTag)
      ..setLength(data.length);
    table.read(null, stream);

    final kerning = table.getHorizontalKerningSubtable();
    expect(kerning, isNotNull);

    expect(kerning!.getPairKerning(10, 5), 0);
    expect(kerning.getPairKerning(10, 6), -20);
    expect(kerning.getPairKerning(11, 6), 20);
    expect(kerning.getPairKerning(11, 4), 0); // glyph outside class table
  });

  test('reads contextual kerning from format 1 subtable', () {
    // (no-op) contextual kerning test
    final subtable = BytesBuilder()
      ..add(_ushort(0)) // subtable version
      ..add(_ushort(0x0030)) // length (48 bytes)
      ..add(_ushort(0x0101)) // coverage: horizontal + format 1
      ..add(_ushort(6)) // stateSize (six classes)
      ..add(_ushort(0x000A)) // classTableOffset
      ..add(_ushort(0x0010)) // stateArrayOffset
      ..add(_ushort(0x001C)) // entryTableOffset
      ..add(_ushort(0x002E)) // valueTableOffset
      ..add(_ushort(3)) // class table: firstGlyph
      ..add(_ushort(2)) // class table: glyphCount
      ..add(<int>[4, 5]) // class assignments: glyph 3 -> 4, glyph 4 -> 5
      ..add(<int>[0, 0, 0, 0, 1, 0]) // state 0 row (default, push, default)
      ..add(<int>[0, 0, 0, 0, 1, 2]) // state 1 row (default, push, apply)
      ..add(_ushort(0x0010)) // entry 0 newState (state 0)
      ..add(_ushort(0x0000)) // entry 0 flags
      ..add(_ushort(0x0016)) // entry 1 newState (state 1)
      ..add(_ushort(0x8000)) // entry 1 flags (push)
      ..add(_ushort(0x0010)) // entry 2 newState (state 0)
      ..add(_ushort(0x002E)) // entry 2 flags (value offset)
      ..add(_short(-41)); // value table: apply -41 and stop

    final bytes = BytesBuilder()
      ..add(_ushort(0)) // table version
      ..add(_ushort(1)) // num subtables
      ..add(subtable.takeBytes());

    final data = Uint8List.fromList(bytes.takeBytes());
    final stream = RandomAccessReadDataStream.fromData(data);

    final table = KerningTable()
      ..setTag(KerningTable.tableTag)
      ..setLength(data.length);
    table.read(null, stream);

    final kerning = table.getHorizontalKerningSubtable();
    expect(kerning, isNotNull);

    expect(kerning!.getPairKerning(3, 4), -41);
    expect(kerning.getPairKerning(4, 3), 0);

    final adjustments = kerning.getKerning(<int>[3, 4, 6]);
    expect(adjustments, <int>[-41, 0, 0]);
  });
}

List<int> _ushort(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

List<int> _short(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

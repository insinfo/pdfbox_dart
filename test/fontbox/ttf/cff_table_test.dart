import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cff_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:test/test.dart';

void main() {
  test('reads and exposes raw cff bytes defensively', () {
    final bytes = Uint8List.fromList(<int>[0x01, 0x02, 0xA0, 0xFF]);

    final table = CffTable()
      ..setTag(CffTable.tableTag)
      ..setOffset(0)
      ..setLength(bytes.length);

    final font = TrueTypeFont();
    table.read(font, RandomAccessReadDataStream.fromData(bytes));

    expect(table.hasData, isTrue);

    final first = table.rawData;
    expect(first, equals(bytes));

    // Mutating the returned list must not affect subsequent callers.
    first[0] = 0x7F;
    expect(table.rawData, equals(bytes));
  });
}

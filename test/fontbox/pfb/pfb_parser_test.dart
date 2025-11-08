import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/pfb/pfb_parser.dart';
import 'package:test/test.dart';

void main() {
  Uint8List _buildSegment(int type, List<int> data) {
    final buffer = <int>[0x80, type];
    final length = data.length;
    buffer
      ..add(length & 0xFF)
      ..add((length >> 8) & 0xFF)
      ..add((length >> 16) & 0xFF)
      ..add((length >> 24) & 0xFF)
      ..addAll(data);
    return Uint8List.fromList(buffer);
  }

  test('parses PFB segments and preserves ordering', () {
    final ascii1 = '%!PS-AdobeFont-1.0\n'.codeUnits;
    final binary = Uint8List.fromList(<int>[0xDE, 0xAD, 0xBE, 0xEF]);
    final ascii2 = 'cleartomark\n'.codeUnits;

    final bytes = <int>[]
      ..addAll(_buildSegment(0x01, ascii1))
      ..addAll(_buildSegment(0x02, binary))
      ..addAll(_buildSegment(0x01, ascii2))
      ..addAll(<int>[0x80, 0x03]);

    final parser = PfbParser(Uint8List.fromList(bytes));

    expect(parser.lengths[0], ascii1.length);
    expect(parser.lengths[1], binary.length);
    expect(parser.lengths[2], ascii2.length);

    expect(parser.segment1, equals(Uint8List.fromList(ascii1)));
    expect(parser.segment2, equals(binary));
    expect(parser.size, ascii1.length + binary.length + ascii2.length);
    expect(parser.data.length, parser.size);

    final expectedOrder = Uint8List.fromList(
      <int>[]..addAll(ascii1)..addAll(binary)..addAll(ascii2),
    );
    expect(parser.data, equals(expectedOrder));
  });
}

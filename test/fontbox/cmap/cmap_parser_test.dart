import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/cmap/cmap_parser.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/cmap_strings.dart';
import 'package:pdfbox_dart/src/fontbox/cmap/predefined_cmap_repository.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:test/test.dart';

void main() {
  const cmapSource = r"""/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CMapName /TestCMap def
1 begincodespacerange
<00> <7F>
endcodespacerange
2 beginbfchar
<41> <0041>
<42> <0042>
endbfchar
1 beginbfrange
<43> <44> <0043>
endbfrange
1 begincidchar
<45> 200
endcidchar
1 begincidrange
<4600> <4602> 300
endcidrange
endcmap
end
end
""";

  group('CMapParser', () {
    test('parses unicode and cid mappings', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(latin1.encode(cmapSource)));
      final cmap = CMapParser().parse(buffer);
      buffer.close();

      expect(cmap.name, 'TestCMap');
      expect(cmap.hasUnicodeMappings(), isTrue);
      expect(cmap.toUnicode(0x41), 'A');
      expect(cmap.toUnicode(0x42), 'B');
      expect(cmap.toUnicode(0x43), 'C');
      expect(cmap.toUnicode(0x44), 'D');
      expect(cmap.toUnicodeBytes(Uint8List.fromList(<int>[0x43])), 'C');

      final codes = cmap.getCodesFromUnicode('A');
      expect(codes, isNotNull);
      expect(codes, orderedEquals(<int>[0x41]));

      expect(cmap.hasCIDMappings(), isTrue);
      expect(cmap.toCID(Uint8List.fromList(<int>[0x45])), 200);
      expect(cmap.toCID(Uint8List.fromList(<int>[0x46, 0x00])), 300);
      expect(cmap.toCID(Uint8List.fromList(<int>[0x46, 0x01])), 301);
      expect(cmap.toCIDFromInt(0x4600), 300);
    });

    test('readCode honours codespace ranges', () {
      final buffer = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(latin1.encode(cmapSource)));
      final cmap = CMapParser().parse(buffer);
      buffer.close();

      final stream = RandomAccessReadBuffer.fromBytes(Uint8List.fromList(<int>[0x41, 0x42, 0x46, 0x00]));
      final first = cmap.readCode(stream);
      expect(first, 0x41);
      final second = cmap.readCode(stream);
      expect(second, 0x42);
      final third = cmap.readCode(stream);
      expect(third, 0x46);
      stream.close();
    });

    test('parses predefined Identity-H', () {
      final parser = CMapParser();
      final cmap = parser.parsePredefined('Identity-H');

      expect(cmap.name, 'Identity-H');
      expect(cmap.hasCIDMappings(), isTrue);
      expect(cmap.toCID(Uint8List.fromList(<int>[0x00, 0x41])), 0x0041);
    });
  });

  group('CMapStrings', () {
    test('provides cached values for one and two byte keys', () {
      final single = CMapStrings.getMapping(Uint8List.fromList(<int>[0x41]));
      final doubleByte = CMapStrings.getMapping(Uint8List.fromList(<int>[0x00, 0x41]));
      final index = CMapStrings.getIndexValue(Uint8List.fromList(<int>[0x00, 0x41]));
      final bytes = CMapStrings.getByteValue(Uint8List.fromList(<int>[0x41]));

      expect(single, 'A');
      expect(doubleByte, 'A');
      expect(index, 0x0041);
      expect(bytes, orderedEquals(<int>[0x41]));
    });
  });

  group('PredefinedCMapRepository', () {
    test('lists bundled CMaps', () {
      final names = PredefinedCMapRepository.list();
      expect(names, isNotEmpty);
      expect(names, contains('Identity-H'));
    });

    test('contains detects known CMap', () {
      expect(PredefinedCMapRepository.contains('Identity-V'), isTrue);
      expect(PredefinedCMapRepository.contains('Unknown-CMap'), isFalse);
    });
  });
}

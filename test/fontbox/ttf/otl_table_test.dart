import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/jstf/jstf_lookup_control.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/otl_table.dart';
import 'package:test/test.dart';

void main() {
  test('parses minimal JSTF table structure', () {
    final bytes = Uint8List.fromList(<int>[
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x6C,
      0x61,
      0x74,
      0x6E,
      0x00,
      0x0C,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x04,
      0x00,
      0x14,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x18,
      0x00,
      0x01,
      0x00,
      0x15,
      0x00,
      0x01,
      0x00,
      0x04,
      0xAA,
      0xBB,
      0xCC,
      0xDD,
    ]);

    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = OtlTable();
    table
      ..setLength(bytes.length)
      ..read(null, stream);

    expect(table.majorVersion, equals(1));
    expect(table.minorVersion, equals(0));
    expect(table.hasScripts, isTrue);

    final script = table.getScript('latn');
    expect(script, isNotNull);
    expect(script!.extenderGlyphs, isEmpty);

    final defaultLangSys = script.defaultLangSys;
    expect(defaultLangSys, isNotNull);
    expect(defaultLangSys!.priorities, hasLength(1));

    final priority = defaultLangSys.priorities.first;
    expect(priority.gsubShrinkageEnable, isNotNull);
    expect(priority.gsubShrinkageEnable!.lookupIndices, <int>[0x15]);
    expect(priority.extensionMax, isNotNull);
    expect(priority.extensionMax!.lookupOffsets, <int>[0x0004]);
  });

  test('JstfPriorityController produces lookup control', () {
    final bytes = Uint8List.fromList(<int>[
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x6C,
      0x61,
      0x74,
      0x6E,
      0x00,
      0x0C,
      0x00,
      0x00,
      0x00,
      0x06,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x04,
      0x00,
      0x14,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x18,
      0x00,
      0x01,
      0x00,
      0x15,
      0x00,
      0x01,
      0x00,
      0x04,
      0xAA,
      0xBB,
      0xCC,
      0xDD,
    ]);

    final stream = RandomAccessReadDataStream.fromData(bytes);
    final table = OtlTable();
    table.setLength(bytes.length);
    table.read(null, stream);

    final script = JstfScript(
      extenderGlyphs: const <int>[],
      defaultLangSys: JstfLangSys(
        <JstfPriority>[
          JstfPriority(
            gsubShrinkageEnable: JstfModList(<int>[0x15]),
          ),
        ],
      ),
      langSysRecords: const <String, JstfLangSys>{},
    );

    final controller =
        JstfPriorityController(script, languageTag: null);
    final control = controller.evaluate(JstfAdjustmentMode.shrink);

    expect(control.hasEnabledGsubLookups, isTrue);
    expect(control.enabledGsubLookups, contains(0x15));
    expect(control.enabledGposLookups, isEmpty);

    final noAdjust = controller.evaluate(JstfAdjustmentMode.none);
    expect(noAdjust.isEmpty, isTrue);
  });
}

import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/vertical_header_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/vertical_metrics_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/vertical_origin_table.dart';
import 'package:test/test.dart';

void main() {
  group('VerticalHeaderTable', () {
    test('parses header fields', () {
      final bytes = BytesBuilder()
        ..add(_fixed32(1, 0))
        ..add(_signedShort(880))
        ..add(_signedShort(-120))
        ..add(_signedShort(40))
        ..add(_unsignedShort(900))
        ..add(_signedShort(50))
        ..add(_signedShort(-30))
        ..add(_signedShort(1024))
        ..add(_signedShort(1))
        ..add(_signedShort(0))
        ..add(_signedShort(12))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_unsignedShort(6));

      final data = Uint8List.fromList(bytes.takeBytes());
      final stream = RandomAccessReadDataStream.fromData(data);
      final table = VerticalHeaderTable()
        ..setTag(VerticalHeaderTable.tableTag)
        ..setLength(data.length);

      table.read(TrueTypeFont(), stream);

      expect(table.version, closeTo(1.0, 1e-6));
      expect(table.ascender, 880);
      expect(table.descender, -120);
      expect(table.lineGap, 40);
      expect(table.advanceHeightMax, 900);
      expect(table.minTopSideBearing, 50);
      expect(table.minBottomSideBearing, -30);
      expect(table.yMaxExtent, 1024);
      expect(table.caretSlopeRise, 1);
      expect(table.caretSlopeRun, 0);
      expect(table.caretOffset, 12);
      expect(table.metricDataFormat, 0);
      expect(table.numberOfVMetrics, 6);
    });
  });

  group('VerticalMetricsTable', () {
    test('reads advance heights and top side bearings', () {
      final font = TrueTypeFont(glyphCount: 4);

      final vheaBytes = BytesBuilder()
        ..add(_fixed32(1, 0))
        ..add(_signedShort(800))
        ..add(_signedShort(-200))
        ..add(_signedShort(0))
        ..add(_unsignedShort(950))
        ..add(_signedShort(20))
        ..add(_signedShort(-10))
        ..add(_signedShort(900))
        ..add(_signedShort(1))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_signedShort(0))
        ..add(_unsignedShort(2));
      final vheaData = Uint8List.fromList(vheaBytes.takeBytes());
      final vheaStream = RandomAccessReadDataStream.fromData(vheaData);
      final header = VerticalHeaderTable()
        ..setTag(VerticalHeaderTable.tableTag)
        ..setLength(vheaData.length);
      header.read(font, vheaStream);
      font.addTable(header);

      final vmtxBytes = BytesBuilder()
        ..add(_unsignedShort(880))
        ..add(_signedShort(30))
        ..add(_unsignedShort(860))
        ..add(_signedShort(25))
        ..add(_signedShort(40))
        ..add(_signedShort(44));
      final vmtxData = Uint8List.fromList(vmtxBytes.takeBytes());
      final metrics = VerticalMetricsTable()
        ..setTag(VerticalMetricsTable.tableTag)
        ..setLength(vmtxData.length);
      metrics.read(font, RandomAccessReadDataStream.fromData(vmtxData));

      expect(metrics.getAdvanceHeight(0), 880);
      expect(metrics.getAdvanceHeight(1), 860);
      expect(metrics.getAdvanceHeight(3), 860);

      expect(metrics.getTopSideBearing(0), 30);
      expect(metrics.getTopSideBearing(1), 25);
      expect(metrics.getTopSideBearing(2), 40);
      expect(metrics.getTopSideBearing(3), 44);
    });
  });

  group('VerticalOriginTable', () {
    test('looks up per-glyph origins', () {
      final bytes = BytesBuilder()
        ..add(_fixed32(1, 0))
        ..add(_signedShort(700))
        ..add(_unsignedShort(2))
        ..add(_unsignedShort(1))
        ..add(_signedShort(680))
        ..add(_unsignedShort(3))
        ..add(_signedShort(660));

      final data = Uint8List.fromList(bytes.takeBytes());
      final table = VerticalOriginTable()
        ..setTag(VerticalOriginTable.tableTag)
        ..setLength(data.length);
      table.read(TrueTypeFont(), RandomAccessReadDataStream.fromData(data));

      expect(table.version, closeTo(1.0, 1e-6));
      expect(table.defaultVertOriginY, 700);
      expect(table.getOriginY(1), 680);
      expect(table.getOriginY(2), 700);
      expect(table.getOriginY(3), 660);
    });
  });
}

List<int> _fixed32(int major, int minor) {
  final value = (major << 16) | (minor & 0xffff);
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

List<int> _signedShort(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

List<int> _unsignedShort(int value) {
  return <int>[(value >> 8) & 0xff, value & 0xff];
}

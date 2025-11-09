import 'dart:typed_data';

import 'package:pdfbox_dart/src/fontbox/io/random_access_read_data_stream.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/os2_windows_metrics_table.dart';
import 'package:test/test.dart';

void main() {
  test('parses OS/2 version 2 metrics', () {
    final bytes = BytesBuilder()
      ..add(_ushort(2)) // version
      ..add(_short(400))
      ..add(_ushort(700))
      ..add(_ushort(Os2WindowsMetricsTable.widthClassMedium))
      ..add(_short(Os2WindowsMetricsTable.fsTypeEditable))
      ..add(_short(650))
      ..add(_short(600))
      ..add(_short(0))
      ..add(_short(50))
      ..add(_short(650))
      ..add(_short(600))
      ..add(_short(0))
      ..add(_short(350))
      ..add(_short(50))
      ..add(_short(30))
      ..add(_short(Os2WindowsMetricsTable.familyClassSansSerif))
      ..add(List<int>.filled(10, 1))
      ..add(_uint(0x00000001))
      ..add(_uint(0x00000002))
      ..add(_uint(0x00000003))
      ..add(_uint(0x00000004))
      ..add(_string('TEST'))
      ..add(_ushort(0x0040))
      ..add(_ushort(32))
      ..add(_ushort(126))
      ..add(_short(800))
      ..add(_short(-200))
      ..add(_short(100))
      ..add(_ushort(900))
      ..add(_ushort(100))
      ..add(_uint(0x11111111))
      ..add(_uint(0x22222222))
      ..add(_short(450))
      ..add(_short(700))
      ..add(_ushort(0x0020))
      ..add(_ushort(0x002D))
      ..add(_ushort(10));

    final data = Uint8List.fromList(bytes.takeBytes());
    final stream = RandomAccessReadDataStream.fromData(data);

    final table = Os2WindowsMetricsTable()
      ..setTag(Os2WindowsMetricsTable.tableTag)
      ..setLength(data.length);
    table.read(null, stream);

    expect(table.version, 2);
    expect(table.averageCharWidth, 400);
    expect(table.weightClass, 700);
    expect(table.widthClass, Os2WindowsMetricsTable.widthClassMedium);
    expect(table.fsType, Os2WindowsMetricsTable.fsTypeEditable);
    expect(table.unicodeRange4, 4);
    expect(table.achVendId, 'TEST');
    expect(table.typoAscender, 800);
    expect(table.winAscent, 900);
    expect(table.codePageRange1, 0x11111111);
    expect(table.height, 450);
    expect(table.capHeight, 700);
    expect(table.defaultChar, 0x20);
    expect(table.breakChar, 0x2D);
    expect(table.maxContext, 10);
  });

  test('downgrades version when optional data missing', () {
    final bytes = BytesBuilder()
      ..add(_ushort(2))
      ..add(_short(300))
      ..add(_ushort(400))
      ..add(_ushort(Os2WindowsMetricsTable.widthClassCondensed))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(List<int>.filled(10, 0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_uint(0))
      ..add(_string('ACME'))
      ..add(_ushort(0))
      ..add(_ushort(0))
      ..add(_ushort(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_short(0))
      ..add(_ushort(0))
      ..add(_ushort(0))
      ..add(_uint(0xAAAAAAAA));

    final data = Uint8List.fromList(bytes.takeBytes());
    final table = Os2WindowsMetricsTable()
      ..setTag(Os2WindowsMetricsTable.tableTag)
      ..setLength(data.length);
    table.read(null, RandomAccessReadDataStream.fromData(data));

    expect(table.version, 0); // downgraded
    expect(table.codePageRange1, 0); // not read from truncated data
  });
}

List<int> _ushort(int value) => <int>[(value >> 8) & 0xff, value & 0xff];

List<int> _short(int value) {
  final encoded = value & 0xffff;
  return <int>[(encoded >> 8) & 0xff, encoded & 0xff];
}

List<int> _uint(int value) => <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

List<int> _string(String value) => value.codeUnits;

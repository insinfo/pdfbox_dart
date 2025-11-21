import 'dart:io';
import 'package:test/test.dart';
import 'package:pdfbox_dart/src/jbig2/segments/region_segment_information.dart';
import 'package:pdfbox_dart/src/jbig2/io/sub_input_stream.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/jbig2/util/combination_operator.dart';

void main() {
  test('RegionSegmentInformation parseHeaderTest', () {
    final file = File('test/jbig2/resources/images/sampledata.jb2');
    if (!file.existsSync()) {
      fail('Test resource not found: ${file.path}');
    }
    final bytes = file.readAsBytesSync();
    final rar = RandomAccessReadBuffer.fromBytes(bytes);
    final sis = SubInputStream(rar, 130, 49);
    
    final rsi = RegionSegmentInformation(sis);
    rsi.parseHeader();
    
    expect(rsi.getBitmapWidth(), 37);
    expect(rsi.getBitmapHeight(), 8);
    expect(rsi.getXLocation(), 4);
    expect(rsi.getYLocation(), 1);
    expect(rsi.getCombinationOperator(), CombinationOperator.OR);
  });
}

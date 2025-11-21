import 'package:pdfbox_dart/src/jbig2/segment_data.dart';
import 'package:pdfbox_dart/src/jbig2/segment_header.dart';
import 'package:pdfbox_dart/src/jbig2/io/sub_input_stream.dart';

class EndOfStripe implements SegmentData {
  late SubInputStream subInputStream;
  int lineNumber = 0;

  @override
  void init(SegmentHeader? header, SubInputStream sis) {
    subInputStream = sis;
    parseHeader();
  }

  void parseHeader() {
    lineNumber = subInputStream.readBits(32) & 0xffffffff;
  }

  int getLineNumber() {
    return lineNumber;
  }
}

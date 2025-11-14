import 'dart:typed_data';

import 'package:pdfbox_dart/src/io/random_access_read_buffer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdfparser/fdf_parser.dart';
import 'package:test/test.dart';

void main() {
  group('FDFParser', () {
    test('parses minimal FDF document', () {
      final buffer = StringBuffer();
      var offset = 0;
      void append(String value) {
        buffer.write(value);
        offset += value.length;
      }

      append('%FDF-1.0\n');
      final obj1Offset = offset;
      append('1 0 obj\n');
      append('<< /FDF << /Fields [ << /T (Field1) /V (Value) >> ] >> >>\n');
      append('endobj\n');
      final xrefOffset = offset;
      append('xref\n');
      append('0 2\n');
      append('0000000000 65535 f \n');
      append('${obj1Offset.toString().padLeft(10, '0')} 00000 n \n');
      append('trailer\n');
      append('<< /Size 2 /Root 1 0 R >>\n');
      append('startxref\n');
      append('$xrefOffset\n');
      append('%%EOF');

      final bytes = Uint8List.fromList(buffer.toString().codeUnits);
      final parser = FDFParser(RandomAccessReadBuffer.fromBytes(bytes));
      final document = parser.parse();

      expect(parser.documentVersion, '1.0');
      final trailer = document.cosDocument.trailer;
      final root = trailer.getCOSDictionary(COSName.root);
      expect(root, isNotNull);

      final fdf = (document.cosDocument.getObjectByNumber(1)!.object as COSDictionary)
          .getCOSDictionary(COSName.get('FDF'))!;
      final fields = fdf.getCOSArray(COSName.get('Fields'))!;
      final field = fields[0] as COSDictionary;
      expect(field.getString(COSName.get('T')), 'Field1');
      expect(field.getString(COSName.get('V')), 'Value');

      document.close();
    });
  });
}

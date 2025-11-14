import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_embedded_file.dart';
import 'package:test/test.dart';

void main() {
  group('PDEmbeddedFile', () {
    test('basic metadata round-trip', () {
      final embedded = PDEmbeddedFile.fromBytes(Uint8List.fromList(<int>[1, 2]));
      embedded.subtype = 'application/octet-stream';
      embedded.size = 2;
      final created = DateTime.utc(2025, 1, 1, 12, 0);
      final modified = DateTime.utc(2025, 2, 1, 12, 0);
      embedded.creationDate = created;
      embedded.modDate = modified;
      embedded.checkSum = 'deadbeef';

      expect(embedded.subtype, 'application/octet-stream');
      expect(embedded.size, 2);
      expect(embedded.creationDate, created);
      expect(embedded.modDate, modified);
      expect(embedded.checkSum, 'deadbeef');

      final params = embedded.cosStream.getCOSDictionary(COSName.params);
      expect(params, isNotNull);
      expect(params!.getInt(COSName.size), 2);
    });

    test('mac metadata pruned when cleared', () {
      final embedded = PDEmbeddedFile.fromBytes(Uint8List(0));
      embedded.macCreator = 'Rsrc';
      embedded.macResFork = 'fork';
      expect(embedded.macCreator, 'Rsrc');
      var params = embedded.cosStream.getCOSDictionary(COSName.params);
      expect(params?.getCOSDictionary(COSName.mac), isNotNull);

      embedded.macCreator = null;
      embedded.macResFork = null;
      params = embedded.cosStream.getCOSDictionary(COSName.params);
      expect(params?.getCOSDictionary(COSName.mac), isNull);
    });

    test('clearing size removes params dictionary', () {
      final embedded = PDEmbeddedFile.fromBytes(Uint8List(0));
      embedded.size = 10;
      expect(embedded.size, 10);

      embedded.size = null;
      expect(embedded.size, isNull);
      expect(embedded.cosStream.getCOSDictionary(COSName.params), isNull);
    });
  });
}

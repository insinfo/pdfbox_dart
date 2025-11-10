import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart';
import 'package:test/test.dart';

void main() {
  group('PDSignature', () {
    test('default dictionary sets type to Sig', () {
      final signature = PDSignature();
      expect(signature.cosObject.getNameAsString(COSName.type), equals('Sig'));
    });

    test('metadata setters store values', () {
      final signature = PDSignature();
      signature.setFilter(PDSignature.filterAdobePpklite);
      signature.setSubFilter(PDSignature.subFilterAdbePkcs7Detached);
      signature.setName('Alice');
      signature.setLocation('Brasil');
      signature.setReason('Autorização');
      signature.setContactInfo('alice@example.com');

      expect(signature.filter, equals('Adobe.PPKLite'));
      expect(signature.subFilter, equals('adbe.pkcs7.detached'));
      expect(signature.name, equals('Alice'));
      expect(signature.location, equals('Brasil'));
      expect(signature.reason, equals('Autorização'));
      expect(signature.contactInfo, equals('alice@example.com'));
    });

    test('byte range stored as direct array', () {
      final signature = PDSignature();
      signature.setByteRange([0, 100, 200, 50]);

      expect(signature.byteRange, equals([0, 100, 200, 50]));
      final cosArray = signature.cosObject.getCOSArray(COSName.byteRange);
      expect(cosArray, isA<COSArray>());
      expect(cosArray!.isDirect, isTrue);
    });

    test('contents stored as hex string', () {
      final signature = PDSignature();
      final data = Uint8List.fromList([0x01, 0xFE, 0xAB]);
      signature.setContents(data);

      final stored = signature.getContents();
      expect(stored, equals(data));
      final cosString =
          signature.cosObject.getDictionaryObject(COSName.contents) as COSString;
      expect(cosString.isHex, isTrue);
    });

    test('sign date round-trips through PDF date format', () {
      final signature = PDSignature();
      final date = DateTime.utc(2024, 5, 1, 12, 30, 45);
      signature.setSignDate(date);

      expect(signature.signDate, equals(date));
      final m = signature.cosObject.getDictionaryObject(COSName.m) as COSString;
      expect(m.string.startsWith('D:'), isTrue);
    });

    test('getSignedContent concatenates ranges', () {
      final signature = PDSignature();
      final pdfBytes = Uint8List.fromList('0123456789ABCDEFGHIJ'.codeUnits);
      signature.setByteRange([0, 5, 10, 5]);

      final signed = signature.getSignedContent(pdfBytes);
      expect(signed, equals(Uint8List.fromList('01234ABCDE'.codeUnits)));
    });

    test('setByteRange validates element count', () {
      final signature = PDSignature();
      expect(() => signature.setByteRange([1, 2, 3]), throwsArgumentError);
    });
  });
}

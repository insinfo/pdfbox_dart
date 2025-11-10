import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_seed_value.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_seed_value_certificate.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_seed_value_mdp.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_seed_value_time_stamp.dart';
import 'package:test/test.dart';

List<List<int>>? _toIntLists(List<Uint8List>? values) =>
  values?.map((bytes) => bytes.toList()).toList();

void main() {
  group('PDSeedValueTimeStamp', () {
    test('stores URL and required flag', () {
      final stamp = PDSeedValueTimeStamp();

      expect(stamp.url, isNull);
      expect(stamp.timestampRequired, isFalse);

      stamp.setUrl('https://tsa.example.com');
      stamp.setTimestampRequired(true);

      expect(stamp.url, 'https://tsa.example.com');
      expect(stamp.timestampRequired, isTrue);
      expect(stamp.isTimestampRequired(), isTrue);

      final dict = stamp.cosObject;
      expect(dict.isDirect, isTrue);
      expect(dict.getString(COSName.url), 'https://tsa.example.com');
      expect(dict.getInt(COSName.ft), 1);

      stamp.setTimestampRequired(false);
      expect(dict.getInt(COSName.ft), 0);
    });
  });

  group('PDSeedValueMDP', () {
    test('accepts P value in range', () {
      final mdp = PDSeedValueMDP();

      expect(mdp.p, equals(0));
      mdp.setP(2);
      expect(mdp.p, equals(2));
      expect(mdp.getP(), equals(2));
      expect(mdp.cosObject.getInt(COSName.p), equals(2));
    });

    test('rejects out-of-range values', () {
      final mdp = PDSeedValueMDP();
      expect(() => mdp.setP(-1), throwsArgumentError);
      expect(() => mdp.setP(4), throwsArgumentError);
    });
  });

  group('PDSeedValue', () {
    test('initialises dictionary as direct SV', () {
      final seed = PDSeedValue();
      final dict = seed.cosObject;

      expect(dict.isDirect, isTrue);
      expect(dict.getCOSName(COSName.type), COSName.sv);

      // Ensure wrapping existing dictionary preserves direct flag
      final wrapped = PDSeedValue(COSDictionary());
      expect(wrapped.cosObject.isDirect, isTrue);
    });

    test('manages constraint flags and entries', () {
      final seed = PDSeedValue();
      final dict = seed.cosObject;

      seed.setFilterRequired(true);
      seed.setSubFilterRequired(true);
      seed.setDigestMethodRequired(true);
      seed.setVRequired(true);
      seed.setReasonRequired(true);
      seed.setLegalAttestationRequired(true);
      seed.setAddRevInfoRequired(true);

      expect(dict.getFlag(COSName.ff, PDSeedValue.flagFilter), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValue.flagSubFilter), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValue.flagDigestMethod), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValue.flagV), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValue.flagReason), isTrue);
  expect(dict.getFlag(COSName.ff, PDSeedValue.flagLegalAttestation), isTrue);
  expect(dict.getFlag(COSName.ff, PDSeedValue.flagAddRevInfo), isTrue);

  seed.setFilterRequired(false);
  expect(dict.containsKey(COSName.ff), isTrue);
  seed.setSubFilterRequired(false);
  seed.setDigestMethodRequired(false);
  seed.setVRequired(false);
  seed.setReasonRequired(false);
  seed.setLegalAttestationRequired(false);
  seed.setAddRevInfoRequired(false);
  expect(dict.getInt(COSName.ff), isNull);
    });

    test('stores filter, subfilters, digest methods, reasons, and legal attestations', () {
      final seed = PDSeedValue();
      final dict = seed.cosObject;

      seed.setFilter(COSName.adobePpklite);
      expect(seed.getFilter(), COSName.adobePpklite.name);

      seed.setSubFilter([COSName.adbePkcs7Detached.name, COSName.etsiCadesDetached.name]);
      expect(seed.getSubFilter(), [COSName.adbePkcs7Detached.name, COSName.etsiCadesDetached.name]);
      expect(dict.getCOSArray(COSName.subFilter)!.length, 2);

      seed.setDigestMethod([
        COSName.digestSha1.name,
        COSName.digestSha256.name,
      ]);
      expect(seed.getDigestMethod(), [COSName.digestSha1.name, COSName.digestSha256.name]);

      expect(
        () => seed.setDigestMethod(['MD5']),
        throwsArgumentError,
      );

      seed.setReasons(['Contract Approval', 'Review']);
  expect(seed.getReasons(), ['Contract Approval', 'Review']);

  seed.setLegalAttestation(['Statement 1']);
  expect(seed.getLegalAttestation(), ['Statement 1']);

  seed.setSubFilter(null);
  seed.setDigestMethod(null);
  seed.setReasons(null);
  seed.setLegalAttestation(null);
  seed.setFilter(null);

  expect(dict.containsKey(COSName.subFilter), isFalse);
  expect(dict.containsKey(COSName.digestMethod), isFalse);
  expect(dict.containsKey(COSName.reasons), isFalse);
  expect(dict.containsKey(COSName.legalAttestation), isFalse);
  expect(dict.containsKey(COSName.filter), isFalse);
    });

    test('wires MDP, certificate, timestamp, and parser version', () {
      final seed = PDSeedValue();

      seed.setV(2.0);
      expect(seed.getV(), closeTo(2.0, 0.0001));
      expect(seed.cosObject.getFloat(COSName.v), closeTo(2.0, 0.0001));

      final mdp = PDSeedValueMDP()..setP(2);
      seed.setMDP(mdp);
      expect(seed.getMDP()!.getP(), 2);

      seed.setMDP(null);
      expect(seed.getMDP(), isNull);

      final certificate = PDSeedValueCertificate();
      seed.setSeedValueCertificate(certificate);
      expect(seed.getSeedValueCertificate(), isNotNull);

      seed.setSeedValueCertificate(null);
      expect(seed.getSeedValueCertificate(), isNull);

      final timeStamp = PDSeedValueTimeStamp()
        ..setUrl('https://tsa.example.com')
        ..setTimestampRequired(true);
      seed.setTimeStamp(timeStamp);
      expect(seed.getTimeStamp()!.url, 'https://tsa.example.com');

      seed.setTimeStamp(null);
      expect(seed.getTimeStamp(), isNull);
    });
  });

  group('PDSeedValueCertificate', () {
    test('initialises dictionary as direct SV cert', () {
      final cert = PDSeedValueCertificate();
      final dict = cert.cosObject;

      expect(dict.isDirect, isTrue);
      expect(dict.getCOSName(COSName.type), COSName.svCert);

      final wrapped = PDSeedValueCertificate(COSDictionary());
      expect(wrapped.cosObject.isDirect, isTrue);
    });

    test('handles flag toggles', () {
      final cert = PDSeedValueCertificate();
      final dict = cert.cosObject;

      cert.setSubjectRequired(true);
      cert.setIssuerRequired(true);
      cert.setOIDRequired(true);
      cert.setSubjectDNRequired(true);
      cert.setKeyUsageRequired(true);
      cert.setURLRequired(true);

      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagSubject), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagIssuer), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagOid), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagSubjectDn), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagKeyUsage), isTrue);
      expect(dict.getFlag(COSName.ff, PDSeedValueCertificate.flagUrl), isTrue);

      cert.setSubjectRequired(false);
      cert.setIssuerRequired(false);
      cert.setOIDRequired(false);
      cert.setSubjectDNRequired(false);
      cert.setKeyUsageRequired(false);
      cert.setURLRequired(false);
      expect(dict.getInt(COSName.ff), isNull);
    });

    test('manages subject and issuer byte arrays', () {
      final cert = PDSeedValueCertificate();
  final subjectA = Uint8List.fromList([1, 2, 3]);
  final subjectB = Uint8List.fromList([4, 5, 6]);

  cert.setSubject([subjectA]);
  expect(_toIntLists(cert.getSubject()), [[1, 2, 3]]);

  cert.addSubject(subjectB);
  expect(_toIntLists(cert.getSubject()), [[1, 2, 3], [4, 5, 6]]);

  cert.removeSubject(subjectA);
  expect(_toIntLists(cert.getSubject()), [[4, 5, 6]]);

  cert.removeSubject(subjectB);
  expect(cert.getSubject(), isNull);

  final issuer = Uint8List.fromList([9, 8, 7]);
  cert.setIssuer([issuer]);
  expect(_toIntLists(cert.getIssuer()), [[9, 8, 7]]);

  cert.addIssuer(subjectA);
  expect(_toIntLists(cert.getIssuer()), [[9, 8, 7], [1, 2, 3]]);

  cert.removeIssuer(issuer);
  expect(_toIntLists(cert.getIssuer()), [[1, 2, 3]]);

  cert.removeIssuer(subjectA);
  expect(cert.getIssuer(), isNull);
    });

    test('manages OID values', () {
      final cert = PDSeedValueCertificate();
  final oid = Uint8List.fromList([10, 11]);
  final oid2 = Uint8List.fromList([12]);

  cert.setOID([oid]);
  expect(_toIntLists(cert.getOID()), [[10, 11]]);

  cert.addOID(oid2);
  expect(_toIntLists(cert.getOID()), [[10, 11], [12]]);

  cert.removeOID(oid);
  expect(_toIntLists(cert.getOID()), [[12]]);

  cert.removeOID(oid2);
  expect(cert.getOID(), isNull);
    });

    test('manages subject distinguished names', () {
      final cert = PDSeedValueCertificate();
      cert.setSubjectDN([
        {'CN': 'Alice', 'O': 'Wonderland Inc.'},
      ]);

      final subjectDN = cert.getSubjectDN();
      expect(subjectDN, isNotNull);
      expect(subjectDN, hasLength(1));
      expect(subjectDN!.first['CN'], 'Alice');
      expect(subjectDN.first['O'], 'Wonderland Inc.');

      cert.setSubjectDN(null);
      expect(cert.getSubjectDN(), isNull);
    });

    test('handles key usage strings and validation', () {
      final cert = PDSeedValueCertificate();

      cert.setKeyUsage(['101010101']);
      expect(cert.getKeyUsage(), ['101010101']);

      cert.addKeyUsage('1XXXXXXXX');
      expect(cert.getKeyUsage(), ['101010101', '1XXXXXXXX']);

      expect(() => cert.addKeyUsage('INVALID'), throwsArgumentError);

      cert.addKeyUsageFlags(
        digitalSignature: '1',
        nonRepudiation: '0',
        keyEncipherment: '0',
        dataEncipherment: 'X',
        keyAgreement: 'X',
        keyCertSign: '1',
        cRLSign: '0',
        encipherOnly: '0',
        decipherOnly: '1',
      );
      expect(cert.getKeyUsage(), ['101010101', '1XXXXXXXX', '100XX1001']);

      cert.removeKeyUsage('101010101');
      expect(cert.getKeyUsage(), ['1XXXXXXXX', '100XX1001']);

      cert.setKeyUsage(null);
      expect(cert.getKeyUsage(), isNull);
    });

    test('stores URL and type', () {
      final cert = PDSeedValueCertificate();

      cert.setURL('https://cert.example.com');
      cert.setURLType('ASSP');

      expect(cert.getURL(), 'https://cert.example.com');
      expect(cert.getURLType(), 'ASSP');

      cert.setURL(null);
      cert.setURLType(null);

      expect(cert.getURL(), isNull);
      expect(cert.getURLType(), isNull);
    });
  });
}
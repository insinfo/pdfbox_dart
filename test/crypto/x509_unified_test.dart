import 'dart:io';

import 'package:pdfbox_dart/src/crypto/x509/core/x509_certificates.dart';
import 'package:pdfbox_dart/crypto_keys.dart' as ck;
import 'package:test/test.dart';

void main() {
  test('X509Certificate parses PEM and DER', () {
    final pem = File('test/resources/user.crt').readAsStringSync();
    final cert = X509Certificate.fromPem(pem);

    expect(cert.der.isNotEmpty, isTrue);
    expect(cert.pem.contains('BEGIN CERTIFICATE'), isTrue);
    expect(cert.signatureValue.isNotEmpty, isTrue);

    final fromDer = X509Certificate.fromDer(cert.der);
    expect(fromDer.der.isNotEmpty, isTrue);
  });

  test('X509Certificate exposes public key', () {
    final pem = File('test/resources/user.crt').readAsStringSync();
    final cert = X509Certificate.fromPem(pem);

    final ck.PublicKey key = cert.publicKey;
    expect(key, isNotNull);
    expect(key is ck.RsaPublicKey || key is ck.EcPublicKey, isTrue);

    final param = cert.getPublicKeyParam();
    expect(param, isNotNull);
  });
}

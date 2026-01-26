import 'dart:io';
import 'dart:typed_data';

import 'package:pdfbox_dart/basic_utils.dart' show CryptoUtils;
import 'package:pdfbox_dart/src/crypto/x509/core/x509_utils.dart'
    show X509Utils;
import 'package:test/test.dart';

void main() {
  test('CryptoUtils parses RSA private key + certificate from PEM', () {
    if (!_hasOpenSsl()) return;

    final Directory testDir = Directory.systemTemp.createTempSync('pem_parse_');
    try {
      _runCmdSync('openssl', <String>[
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-keyout',
        '${testDir.path}/user_key.pem',
        '-out',
        '${testDir.path}/user_cert.pem',
        '-days',
        '365',
        '-nodes',
        '-subj',
        '/CN=Jane Doe',
      ]);

      final String privateKeyPem =
          File('${testDir.path}/user_key.pem').readAsStringSync();
      final String certificatePem =
          File('${testDir.path}/user_cert.pem').readAsStringSync();

      final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
      final Uint8List certDer = X509Utils.pemToDer(certificatePem);

      expect(privateKey.modulus, isNotNull);
      expect(privateKey.privateExponent, isNotNull);
      expect(certDer, isNotEmpty);
    } finally {
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
    }
  });
}

bool _hasOpenSsl() {
  try {
    final ProcessResult result =
        Process.runSync('openssl', const <String>['version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void _runCmdSync(String exe, List<String> args) {
  final ProcessResult result = Process.runSync(exe, args);
  if (result.exitCode != 0) {
    throw StateError(
      'Command failed: $exe ${args.join(' ')}\n'
      'stdout: ${result.stdout}\n'
      'stderr: ${result.stderr}',
    );
  }
}

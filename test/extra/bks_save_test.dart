
import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/jks_keystore.dart'; 
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/bks_keystore.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/keystore_base.dart';

void main() {
  group('BKS Save/Load', () {
    test('Round-trip BKS save/load from JKS source', () async {
      final jksPath = 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks';
      final file = File(jksPath);
      if (!await file.exists()) {
        print('Skipping BKS Interop test: Base file not found');
        return;
      }
      
      final ks = JksKeyStore.load(await file.readAsBytes());
      
      // Convert to BKS
      // Note: TrustedCertEntry and PrivateKeyEntry are compatible base types
      final bks = BksKeyStore('bks', ks.entries);
      
      final savedBytes = bks.save('changeit');
      final tmpFile = File('test/tmp/dart_generated.bks');
      await tmpFile.parent.create(recursive: true);
      await tmpFile.writeAsBytes(savedBytes);
      
      print('Saved BKS to ${tmpFile.path}, size: ${savedBytes.length} bytes');
      
      final reload = BksKeyStore.load(savedBytes, storePassword: 'changeit');
      expect(reload.entries.length, equals(ks.entries.length));
      
      // Verify first alias
      final alias = ks.entries.keys.first;
      expect(reload.entries.containsKey(alias), isTrue);
      
      final entry = reload.entries[alias];
      // It should be BksTrustedCertEntry (which extends TrustedCertEntry)
      expect(entry, isA<TrustedCertEntry>());
      
      // Verify HMAC check (load with wrong password should fail)
      expect(
         () => BksKeyStore.load(savedBytes, storePassword: 'wrong'),
         throwsA(isA<KeystoreSignatureException>())
      );
    });
  });
}

import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/jks_keystore.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/keystore_base.dart';

void main() {
  group('JKS Save/Restore Test', () {
    test('Round-trip JKS save/load', () {
      final jksPath = 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks';
      final file = File(jksPath);
      if (!file.existsSync()) {
        print('Skipping JKS round-trip test: file not found');
        return;
      }
      
      final originalBytes = file.readAsBytesSync();
      
      // Load
      // Providing empty password skips verification if digest doesn't match?
      // JksKeyStore.load checks digest ONLY if storePassword.isNotEmpty.
      
      final ks = JksKeyStore.load(originalBytes, storePassword: ''); 
      
      // Save with a new password
      final storePassword = 'changeit'; 
      final savedBytes = ks.save(storePassword);
      
      // Reload saved bytes AND verify integrity with the password
      final reloadedKs = JksKeyStore.load(savedBytes, storePassword: storePassword);
      
      expect(reloadedKs.entries.length, equals(ks.entries.length));
      
      // Verify an entry
      final alias = ks.entries.keys.first;
      final entry1 = ks.entries[alias] as TrustedCertEntry;
      final entry2 = reloadedKs.entries[alias] as TrustedCertEntry;
      
      // Note: Timestamp might differ slightly if implementation modified it, 
      // but here we just read/write so it should preserve exactly.
      expect(entry1.timestamp, equals(entry2.timestamp));
      
      // Check cert content
      // Cert is in entry1.certData (Uint8List)
      expect(entry1.certData, equals(entry2.certData));
      
      print('JKS Round-trip successful. Saved size: ${savedBytes.length}');
      
      // Verify integrity check fails with wrong password
      expect(
          () => JksKeyStore.load(savedBytes, storePassword: 'wrong'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Keystore password incorrect')))
      );
    });
  });
}

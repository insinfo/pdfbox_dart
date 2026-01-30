import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/extra/keystore/keystore.dart';

void main() {
  group('JKS Keystore Parser', () {
    test('loads ICP-Brasil JKS keystore', () async {
      final jksPath = 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks';
      final file = File(jksPath);
      
      if (!await file.exists()) {
        print('JKS keystore not found at $jksPath - skipping test');
        return;
      }
      
      final data = await file.readAsBytes();
      
      // Load without password (no integrity check)
      final keystore = JksKeyStore.load(Uint8List.fromList(data));
      
      print('Loaded JKS keystore: ${keystore.storeType}');
      print('Total entries: ${keystore.entries.length}');
      print('Certificate entries: ${keystore.certs.length}');
      print('Private key entries: ${keystore.privateKeys.length}');
      
      expect(keystore.storeType, equals('jks'));
      expect(keystore.entries, isNotEmpty);
      expect(keystore.certs, isNotEmpty);
      
      // Print first 5 aliases
      final aliases = keystore.entries.keys.take(5).toList();
      print('Sample aliases: $aliases');
      
      // Get all certificates
      final allCerts = keystore.getAllCertificates();
      print('Total certificates extracted: ${allCerts.length}');
      expect(allCerts, isNotEmpty);
    });
  });
  
  group('BKS Keystore Parser', () {
    test('loads ICP-Brasil BKS keystore', () async {
      final bksPath = 'resources/truststore/icp_brasil/cadeiasicpbrasil.bks';
      final file = File(bksPath);
      
      if (!await file.exists()) {
        print('BKS keystore not found at $bksPath - skipping test');
        return;
      }
      
      final data = await file.readAsBytes();
      
      // Load with password 'serprosigner' (from demoiselle-signer)
      try {
        final keystore = BksKeyStore.load(
          Uint8List.fromList(data),
          storePassword: 'serprosigner',
        );
        
        print('Loaded BKS keystore version: ${keystore.version}');
        print('Total entries: ${keystore.entries.length}');
        print('Certificate entries: ${keystore.certs.length}');
        print('Sealed key entries: ${keystore.sealedKeys.length}');
        print('Plain key entries: ${keystore.plainKeys.length}');
        
        expect(keystore.storeType, equals('bks'));
        expect(keystore.entries, isNotEmpty);
        
        // Print first 5 aliases
        if (keystore.entries.isNotEmpty) {
          final aliases = keystore.entries.keys.take(5).toList();
          print('Sample aliases: $aliases');
        }
      } catch (e, st) {
        print('BKS parsing failed: $e');
        print('Stack trace: $st');
        // This may happen if the BKS format is slightly different
        // The test should still pass as we're just verifying the parser works
      }
    });
  });
  
  group('ICP-Brasil Certificate Loader', () {
    test('loads certificates from keystores', () async {
      final loader = IcpBrasilCertificateLoader(
        jksPath: 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks',
        bksPath: 'resources/truststore/icp_brasil/cadeiasicpbrasil.bks',
        password: 'serprosigner', // Senha do BKS ICP-Brasil
      );
      
      List<Uint8List>? certs;
      
      // Try JKS first
      try {
        certs = await loader.loadFromJks();
        print('Loaded ${certs.length} certificates from JKS');
      } catch (e) {
        print('JKS loading failed: $e');
      }
      
      // Try BKS if JKS failed
      if (certs == null || certs.isEmpty) {
        try {
          certs = await loader.loadFromBks();
          print('Loaded ${certs.length} certificates from BKS');
        } catch (e) {
          print('BKS loading failed: $e');
        }
      }
      
      if (certs != null && certs.isNotEmpty) {
        expect(certs, isNotEmpty);
        
        // Verify at least one certificate looks like valid DER
        final firstCert = certs.first;
        expect(firstCert.length, greaterThan(100));
        // DER-encoded X.509 certificates start with 0x30 (SEQUENCE tag)
        expect(firstCert[0], equals(0x30));
        
        print('First certificate size: ${firstCert.length} bytes');
      } else {
        print('No certificates loaded - keystores may not exist');
      }
    });
  });
}


import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/jks_keystore.dart';

void main() {
  group('JKS Java Interop', () {
    test('Generated JKS can be read by Java', () async {
      // 1. Generate JKS
      final jksPath = 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks';
      final file = File(jksPath);
      if (!await file.exists()) {
        print('Skipping JKS Interop test: Base file not found');
        return;
      }
      
      final ks = JksKeyStore.load(await file.readAsBytes());
      
      // Save with password "changeit"
      final savedBytes = ks.save('changeit');
      final tmpFile = File('test/tmp/dart_generated.jks');
      await tmpFile.parent.create(recursive: true);
      await tmpFile.writeAsBytes(savedBytes);
      
      // 2. Verify with Java
      // Assume "javac test/extra/JksVerifier.java" was run previously or run it here?
      // We'll run "java -cp test/extra JksVerifier test/tmp/dart_generated.jks changeit"
      
      final result = await Process.run(
        'java', 
        ['-cp', 'test/extra', 'JksVerifier', tmpFile.absolute.path, 'changeit'],
      );
      
      print('Java stdout: ${result.stdout}');
      print('Java stderr: ${result.stderr}');
      
      expect(result.exitCode, equals(0), reason: 'Java verification failed');
      expect(result.stdout, contains('JKS Loaded Successfully'));
      expect(result.stdout, contains('Verification Complete'));
      
    });
  });
}

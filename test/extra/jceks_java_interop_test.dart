
import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/extra/keystore/jks_keystore.dart';

void main() {
  group('JCEKS Java Interop', () {
    test('Generated JCEKS can be read by Java', () async {
      final jksPath = 'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks';
      final file = File(jksPath);
      if (!await file.exists()) {
        print('Skipping JCEKS Interop test: Base file not found');
        return;
      }
      
      final ks = JksKeyStore.load(await file.readAsBytes());
      
      final savedBytes = ks.saveJceks('changeit');
      final tmpFile = File('test/tmp/dart_generated.jceks');
      await tmpFile.parent.create(recursive: true);
      await tmpFile.writeAsBytes(savedBytes);
      
      // Verify with Java JksVerifier (modified to support JCEKS type?)
      // The provided JksVerifier.java hardcodes "JKS".
      // We should create a JceksVerifier.java
      
      final verifierSource = """
import java.io.FileInputStream;
import java.security.KeyStore;
import java.util.Enumeration;

public class JceksVerifier {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: java JceksVerifier <jceks_file> <password>");
            System.exit(1);
        }

        String fileName = args[0];
        char[] password = args[1].toCharArray();

        try {
            KeyStore ks = KeyStore.getInstance("JCEKS");
            FileInputStream fis = new FileInputStream(fileName);
            ks.load(fis, password);
            fis.close();
            
            System.out.println("JCEKS Loaded Successfully");
            System.out.println("Size: " + ks.size());
            
            Enumeration<String> aliases = ks.aliases();
            while (aliases.hasMoreElements()) {
                String alias = aliases.nextElement();
                 if (ks.isKeyEntry(alias)) {
                     try {
                        ks.getKey(alias, password);
                     } catch (Exception e) {
                        System.err.println("Failed to recover key for alias: " + alias);
                        e.printStackTrace();
                        System.exit(2);
                     }
                }
            }
            System.out.println("Verification Complete");
            
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
""";
      final sourceFile = File('test/extra/JceksVerifier.java');
      await sourceFile.writeAsString(verifierSource);
      
      // Compile
      await Process.run('javac', ['test/extra/JceksVerifier.java']);
      
      final result = await Process.run(
        'java', 
        ['-cp', 'test/extra', 'JceksVerifier', tmpFile.absolute.path, 'changeit'],
      );
      
      print('Java stdout: ${result.stdout}');
      print('Java stderr: ${result.stderr}');
      
      expect(result.exitCode, equals(0), reason: 'Java verification failed');
      expect(result.stdout, contains('JCEKS Loaded Successfully'));
      expect(result.stdout, contains('Verification Complete'));
    });
  });
}

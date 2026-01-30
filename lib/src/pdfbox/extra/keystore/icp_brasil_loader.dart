import 'dart:io';
import 'dart:typed_data';

import 'jks_keystore.dart';
import 'bks_keystore.dart';

/// Loader for ICP-Brasil trusted root certificates.
///
/// This class provides methods to load trusted CA certificates from
/// JKS and BKS keystores distributed with the pdfbox_dart package.
///
/// Usage:
/// ```dart
/// final loader = IcpBrasilCertificateLoader();
/// final certificates = await loader.loadTrustedCertificates();
/// ```
class IcpBrasilCertificateLoader {
  /// Path to the JKS keystore.
  final String? jksPath;
  
  /// Path to the BKS keystore.
  final String? bksPath;
  
  /// Password for the keystores (default is empty string for most ICP-Brasil keystores).
  final String password;
  
  /// Creates a new loader with optional custom paths.
  /// 
  /// If paths are not provided, the loader will look for keystores in
  /// standard locations relative to the package.
  IcpBrasilCertificateLoader({
    this.jksPath,
    this.bksPath,
    this.password = '',
  });
  
  /// Loads trusted certificates from the JKS keystore.
  /// 
  /// Returns a list of DER-encoded X.509 certificates.
  /// Throws if the keystore cannot be loaded.
  Future<List<Uint8List>> loadFromJks() async {
    final path = jksPath ?? _findJksPath();
    if (path == null) {
      throw FileSystemException('JKS keystore not found');
    }
    
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('JKS keystore not found', path);
    }
    
    final data = await file.readAsBytes();
    
    // Try to load without password first (for read-only cert access)
    // If that fails, try with password for full verification
    JksKeyStore keystore;
    try {
      keystore = JksKeyStore.load(Uint8List.fromList(data));
    } catch (e) {
      if (password.isNotEmpty) {
        keystore = JksKeyStore.load(
          Uint8List.fromList(data),
          storePassword: password,
        );
      } else {
        rethrow;
      }
    }
    
    return keystore.getAllCertificates();
  }
  
  /// Loads trusted certificates from the BKS keystore.
  /// 
  /// Returns a list of DER-encoded X.509 certificates.
  /// Throws if the keystore cannot be loaded.
  Future<List<Uint8List>> loadFromBks() async {
    final path = bksPath ?? _findBksPath();
    if (path == null) {
      throw FileSystemException('BKS keystore not found');
    }
    
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('BKS keystore not found', path);
    }
    
    final data = await file.readAsBytes();
    
    // Try to load without password first
    BksKeyStore keystore;
    try {
      keystore = BksKeyStore.load(Uint8List.fromList(data));
    } catch (e) {
      if (password.isNotEmpty) {
        keystore = BksKeyStore.load(
          Uint8List.fromList(data),
          storePassword: password,
        );
      } else {
        rethrow;
      }
    }
    
    return _extractCertificates(keystore);
  }
  
  /// Loads trusted certificates from either keystore (prefers JKS).
  /// 
  /// Returns a list of DER-encoded X.509 certificates.
  /// Tries JKS first, then BKS if JKS fails.
  Future<List<Uint8List>> loadTrustedCertificates() async {
    try {
      return await loadFromJks();
    } catch (e) {
      // Try BKS as fallback
      return await loadFromBks();
    }
  }
  
  /// Synchronously loads certificates from JKS.
  List<Uint8List> loadFromJksSync() {
    final path = jksPath ?? _findJksPath();
    if (path == null) {
      throw FileSystemException('JKS keystore not found');
    }
    
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('JKS keystore not found', path);
    }
    
    final data = file.readAsBytesSync();
    
    JksKeyStore keystore;
    try {
      keystore = JksKeyStore.load(Uint8List.fromList(data));
    } catch (e) {
      if (password.isNotEmpty) {
        keystore = JksKeyStore.load(
          Uint8List.fromList(data),
          storePassword: password,
        );
      } else {
        rethrow;
      }
    }
    
    return keystore.getAllCertificates();
  }
  
  /// Synchronously loads certificates from BKS.
  List<Uint8List> loadFromBksSync() {
    final path = bksPath ?? _findBksPath();
    if (path == null) {
      throw FileSystemException('BKS keystore not found');
    }
    
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('BKS keystore not found', path);
    }
    
    final data = file.readAsBytesSync();
    
    BksKeyStore keystore;
    try {
      keystore = BksKeyStore.load(Uint8List.fromList(data));
    } catch (e) {
      if (password.isNotEmpty) {
        keystore = BksKeyStore.load(
          Uint8List.fromList(data),
          storePassword: password,
        );
      } else {
        rethrow;
      }
    }
    
    return _extractCertificates(keystore);
  }
  
  /// Synchronously loads certificates from either keystore.
  List<Uint8List> loadTrustedCertificatesSync() {
    try {
      return loadFromJksSync();
    } catch (e) {
      return loadFromBksSync();
    }
  }
  
  /// Extracts all certificates from a BKS keystore.
  List<Uint8List> _extractCertificates(BksKeyStore keystore) {
    final result = <Uint8List>[];
    
    for (final entry in keystore.entries.values) {
      if (entry is BksTrustedCertEntry) {
        result.add(entry.certData);
      } else if (entry is BksKeyEntry) {
        for (final cert in entry.certChain) {
          result.add(cert.certData);
        }
      } else if (entry is BksSealedKeyEntry) {
        for (final cert in entry.certChain) {
          result.add(cert.certData);
        }
        if (entry.isDecrypted()) {
          for (final cert in entry.nestedEntry.certChain) {
            result.add(cert.certData);
          }
        }
      }
    }
    
    return result;
  }
  
  /// Finds the JKS keystore path.
  String? _findJksPath() {
    final candidates = [
      'resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks',
      '../resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks',
      '../../resources/truststore/keystore_icp_brasil/keystore_ICP_Brasil.jks',
    ];
    
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    
    return null;
  }
  
  /// Finds the BKS keystore path.
  String? _findBksPath() {
    final candidates = [
      'resources/truststore/icp_brasil/cadeiasicpbrasil.bks',
      '../resources/truststore/icp_brasil/cadeiasicpbrasil.bks',
      '../../resources/truststore/icp_brasil/cadeiasicpbrasil.bks',
    ];
    
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    
    return null;
  }
}

/// Extension to add ICP-Brasil support to TrustedRootsProvider.
extension IcpBrasilExtension on List<Uint8List> {
  /// Converts a list of DER-encoded certificates to a format suitable
  /// for use with PdfSignatureValidator.
  List<Uint8List> get asTrustedRoots => this;
}

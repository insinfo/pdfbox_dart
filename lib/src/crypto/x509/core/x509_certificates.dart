// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as pc_asn1;

import '../../../io/stream_reader.dart';
import '../../asn1/core/legacy_asn1.dart';
import '../../asn1/core/legacy_asn1_stream.dart';
import '../../asn1/core/legacy_der.dart';
import '../../basic_utils/core/crypto_utils.dart';
import '../../crypto_keys/crypto_keys.dart' as ck;
import '../../cryptography/cipher_block_chaining_mode.dart';
import '../pkcs7_x509.dart';
import '../../pkcs/core/common.dart';

import 'x509_name.dart';
import 'x509_time.dart';
import '../../../pdfbox/extra/pkcs/pfx_data.dart';

/// Helper to wrap Asn1 in Asn1Encode
class Asn1Wrapper extends Asn1Encode {
  final Asn1 _asn1;
  Asn1Wrapper(this._asn1);
  @override Asn1 getAsn1() => _asn1;
}

class Asn1RsaPublicKey extends Asn1Encode {
    Asn1RsaPublicKey(this.modulus, this.exponent);
    final BigInt modulus;
    final BigInt exponent;

  BigInt get publicExponent => exponent;
    
    static Asn1RsaPublicKey? getPublicKey(dynamic obj) {
    if (obj is Asn1RsaPublicKey) return obj;
    final Asn1Sequence? seq = Asn1Sequence.getSequence(obj);
    if (seq == null || seq.count < 2) return null;
    final Asn1? modObj = seq[0]?.getAsn1();
    final Asn1? expObj = seq[1]?.getAsn1();
    if (modObj is DerInteger && expObj is DerInteger) {
      return Asn1RsaPublicKey(modObj.value, expObj.value);
    }
    return null;
    }

    @override
    Asn1 getAsn1() {
         final c = Asn1EncodeCollection();
         c.encodableObjects.add(Asn1Wrapper(DerInteger.fromNumber(modulus)));
         c.encodableObjects.add(Asn1Wrapper(DerInteger.fromNumber(exponent)));
         return DerSequence(collection: c);
    }
}

class PublicKeyInformation extends Asn1Encode {
    PublicKeyInformation(this.algorithm, this.publicKeyAsn1);
    final Algorithms algorithm;
    final Asn1Encode? publicKeyAsn1; 
    
    DerBitString? get publicKey {
      if (publicKeyAsn1 == null) return null;
      if (publicKeyAsn1 is DerBitString) return publicKeyAsn1 as DerBitString;
      final Asn1? asn1 = publicKeyAsn1!.getAsn1();
      final List<int>? der = asn1?.getDerEncoded();
      if (der == null || der.isEmpty) return null;
      return DerBitString(der, 0);
    }

    Asn1? getPublicKey() {
   final DerBitString? bit = publicKey;
   final List<int>? bytes = bit?.getBytes();
   if (bytes == null || bytes.isEmpty) return null;
   return Asn1Stream(PdfStreamReader(Uint8List.fromList(bytes))).readAsn1();
    }
    
    @override
    Asn1 getAsn1() {
        final collection = Asn1EncodeCollection();
        collection.encodableObjects.add(algorithm);
        if (publicKey != null) {
            collection.encodableObjects.add(Asn1Wrapper(publicKey!));
        }
        return DerSequence(collection: collection);
   }
}

class X509CertificateStructure extends Asn1Encode {
    X509CertificateStructure(this.asn1) {
    if (asn1.objects!.isNotEmpty && asn1.objects![0] is Asn1Tag && (asn1.objects![0] as Asn1Tag).tagNumber == 0) {
            _offset = 0;
        } else {
            _offset = -1;
        }
    }
    final Asn1Sequence asn1;
    late int _offset;
    
    static X509CertificateStructure getInstance(dynamic obj) {
        if (obj is X509CertificateStructure) return obj;
      if (obj is Asn1Sequence) {
        // If a full Certificate SEQUENCE is provided, unwrap the TBS sequence.
        if (obj.count >= 3 &&
          obj[0]?.getAsn1() is Asn1Sequence &&
          obj[1]?.getAsn1() is Asn1Sequence &&
          obj[2]?.getAsn1() is DerBitString) {
          final Asn1Sequence tbs = obj[0]!.getAsn1()! as Asn1Sequence;
          return X509CertificateStructure(tbs);
        }
        return X509CertificateStructure(obj);
      }
        throw Exception('Invalid type for X509CertificateStructure');
    }
    
    X509Name? get issuer => _getAsSequence(_offset + 3) != null ? X509Name(_getAsSequence(_offset + 3)!) : null;
    X509Name? get subject => _getAsSequence(_offset + 5) != null ? X509Name(_getAsSequence(_offset + 5)!) : null;
    
    // Serial number as DerInteger for .value/.positiveValue access
    DerInteger? get serialNumber {
       final Asn1Encode? obj = asn1.objects![_offset + 1] as Asn1Encode?;
       if (obj is DerInteger) return obj;
       if (obj is Asn1) {
        final List<int>? der = obj.getDerEncoded();
        if (der == null || der.isEmpty) return null;
        final Asn1? parsed =
           Asn1Stream(PdfStreamReader(Uint8List.fromList(der))).readAsn1();
        if (parsed is DerInteger) return parsed;
       }
       return null;
    }
    
    X509Time? get startDate => _getTime(_offset + 4, 0);
    X509Time? get endDate => _getTime(_offset + 4, 1);
    
    PublicKeyInformation? get subjectPublicKeyInfo {
         final seq = _getAsSequence(_offset + 6);
       if (seq == null || seq.count < 2) return null;
       final Asn1? algObj = seq[0]?.getAsn1();
       final Asn1Sequence? algSeq = Asn1Sequence.getSequence(algObj);
       if (algSeq == null) return null;
       final Algorithms alg = Algorithms.fromSequence(algSeq);
       final Asn1Encode? pk = seq[1] as Asn1Encode?;
       return PublicKeyInformation(alg, pk);
    }
    
    // Legacy needs
    Algorithms? get signatureAlgorithm => null; // TODO

    Asn1Sequence? _getAsSequence(int index) {
        if (index >= asn1.objects!.length) return null;
        return asn1.objects![index] as Asn1Sequence?;
    }
    
    X509Time? _getTime(int seqIndex, int timeIndex) {
        final seq = _getAsSequence(seqIndex);
        if (seq == null || timeIndex >= seq.objects!.length) return null;
        return X509Time.getTime(seq.objects![timeIndex]);
    }
    
    @override
    Asn1 getAsn1() => asn1;
}

/// internal class
class IX509Extension {
  /// internal method
  Asn1Octet? getExtension(DerObjectID id) => null;
}

/// internal class
class X509Certificates {
  /// internal constructor
  X509Certificates(X509Certificate certificate) {
    _certificate = certificate;
  }
  //Fields
  X509Certificate? _certificate;
  //Properties
  /// internal property
  X509Certificate? get certificate => _certificate;
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => _certificate.hashCode;
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (other is X509Certificates) {
      return _certificate == other._certificate;
    } else {
      return false;
    }
  }
}

/// internal class
abstract class X509ExtensionBase implements IX509Extension {
  /// internal method
  X509Extensions? getX509Extensions();
  @override
  Asn1Octet? getExtension(DerObjectID oid) {
    final X509Extensions? exts = getX509Extensions();
    if (exts != null) {
      final X509Extension? ext = exts.getExtension(oid);
      if (ext != null) {
        return ext._value;
      }
    }
    return null;
  }
}

/// internal class
class X509Extension {
  /// internal constructor
  X509Extension(bool critical, Asn1Octet? value) {
    _critical = critical;
    _value = value;
  }
  //Fields
  bool? _critical;
  Asn1Octet? _value;
  //Implementation
  /// internal method
  static Asn1? convertValueToObject(X509Extension ext) {
    return Asn1Stream(PdfStreamReader(ext._value!.getOctets())).readAsn1();
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (other is X509Extension) {
      return _value == other._value && _critical == other._critical;
    } else {
      return false;
    }
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => _critical! ? _value.hashCode : ~_value.hashCode;
}

/// internal class
class X509Extensions extends Asn1Encode {
  /// internal constructor
  X509Extensions(
    Map<DerObjectID, X509Extension> extensions, [
    List<DerObjectID?>? ordering,
  ]) {
    _extensions = <DerObjectID?, X509Extension?>{};
    if (ordering == null) {
      final List<DerObjectID?> der = <DerObjectID?>[];
      // ignore: avoid_function_literals_in_foreach_calls
      extensions.keys.forEach((DerObjectID? col) {
        der.add(col);
      });
      _ordering = der;
    } else {
      _ordering = ordering;
    }
    // ignore: avoid_function_literals_in_foreach_calls
    _ordering.forEach((DerObjectID? oid) {
      _extensions[oid] = extensions[oid!];
    });
  }

  /// internal method
  X509Extensions.fromSequence(Asn1Sequence seq) {
    _ordering = <DerObjectID?>[];
    _extensions = <DerObjectID?, X509Extension?>{};
    for (int i = 0; i < seq.objects!.length; i++) {
      final Asn1Encode ae = seq.objects![i] as Asn1Encode;
      final Asn1Sequence s = Asn1Sequence.getSequence(ae.getAsn1())!;
      
      final DerObjectID? oid = DerObjectID.getID(s[0]!.getAsn1());
      final bool isCritical =
          s.count == 3 && (s[1]!.getAsn1()! as DerBoolean).isTrue;
      final Asn1Octet? octets = Asn1Octet.getOctetStringFromObject(
        s[s.count - 1]!.getAsn1(),
      );
      _extensions[oid] = X509Extension(isCritical, octets);
      _ordering.add(oid);
    }
  }

  /// internal method
  static X509Extensions? getInstance(dynamic obj, [bool? explicitly]) {
    X509Extensions? result;
    if (explicitly == null) {
      if (obj == null || obj is X509Extensions) {
        result = obj as X509Extensions?;
      } else if (obj is Asn1Sequence) {
        result = X509Extensions.fromSequence(obj);
      } else if (obj is Asn1Tag) {
        result = getInstance(obj.getObject());
      } else {
        return null; 
      }
    } else {
      result = getInstance(Asn1Sequence.getSequence(obj, explicitly));
    }
    return result;
  }

  //Fields
  late Map<DerObjectID?, X509Extension?> _extensions;
  late List<DerObjectID?> _ordering;

  /// internal field
  static DerObjectID authorityKeyIdentifier = DerObjectID('2.5.29.35');

  /// internal field
  static DerObjectID crlDistributionPoints = DerObjectID('2.5.29.31');

  /// internal field
  static DerObjectID authorityInfoAccess = DerObjectID('1.3.6.1.5.5.7.1.1');

  //Implementation
  @override
  Asn1 getAsn1() {
    final Asn1EncodeCollection vec = Asn1EncodeCollection();
    // ignore: avoid_function_literals_in_foreach_calls
    _ordering.forEach((DerObjectID? oid) {
      final X509Extension ext = _extensions[oid]!;
      final Asn1EncodeCollection v = Asn1EncodeCollection(<Asn1Encode?>[oid]);
      if (ext._critical!) {
        v.encodableObjects.add(DerBoolean(true));
      }
      v.encodableObjects.add(ext._value);
      vec.encodableObjects.add(DerSequence(collection: v));
    });
    return DerSequence(collection: vec);
  }

  /// internal method
  X509Extension? getExtension(DerObjectID oid) {
    return (_extensions.containsKey(oid)) ? _extensions[oid] : null;
  }
}

/// Internal wrapper using PointyCastle implementation
class X509Certificate extends X509ExtensionBase {
  final X509 _impl;
  
  X509Certificate(this._impl);
    factory X509Certificate.fromDer(Uint8List der) {
      return X509Certificate(X509.fromDer(der));
    }

    factory X509Certificate.fromPem(String pem) {
      return X509Certificate(X509.fromPem(pem));
    }

    pc_asn1.ASN1Sequence get asn1 => _impl.asn1;

    pc_asn1.ASN1Sequence get asn1Issuer => _impl.asn1Issuer;

    Uint8List get der => _impl.der;

    String get pem => _impl.pem;

    pc_asn1.ASN1ObjectIdentifier get signatureAlgorithmOI =>
        _impl.signatureAlgorithmOI;

    pc_asn1.ASN1Object get signatureParameters => _impl.signatureParameters;

    Uint8List get signatureValue => _impl.signatureValue;

    HashAlgorithm get digestAlgorithm => _impl.digestAlgorithm;

    Uint8List get body => _impl.body;

    DateTime get notBefore => _impl.notBefore;

    DateTime get notAfter => _impl.notAfter;

      Iterable<MapEntry<pc_asn1.ASN1ObjectIdentifier, dynamic>> get issuer =>
        _impl.issuer;

      Iterable<MapEntry<pc_asn1.ASN1ObjectIdentifier, dynamic>> get subject =>
        _impl.subject;

    Uint8List get fingerprint => _impl.fingerprint;

    Uint8List generateSignature(
      pc.RSAPrivateKey privateKey,
      Uint8List message,
      HashAlgorithm digestAlgorithm,
    ) {
      return _impl.generateSignature(privateKey, message, digestAlgorithm);
    }

    bool verifySignature(
      Uint8List signature,
      Uint8List message,
      HashAlgorithm digestAlgorithm,
    ) {
      return _impl.verifySignature(signature, message, digestAlgorithm);
    }

    List<X509Certificate> verifyChain(
      List<X509Certificate> chain,
      List<X509Certificate> trusted,
    ) {
      final List<X509> chainImpl = chain.map((c) => c._impl).toList();
      final List<X509> trustedImpl = trusted.map((c) => c._impl).toList();
      final List<X509> verified = _impl.verifyChain(chainImpl, trustedImpl);
      return verified.map((c) => X509Certificate(c)).toList();
    }
  
  // Backwards compatibility factory/conversion
  factory X509Certificate.fromStructure(X509CertificateStructure s) {
      final List<int>? der = s.getAsn1().getDerEncoded();
      if (der == null || der.isEmpty) {
        throw StateError('Invalid certificate DER');
      }
      final x509 = X509.fromDer(Uint8List.fromList(der));
      final cert = X509Certificate(x509);
      cert._c = s;
      return cert;
  }

  X509CertificateStructure? _c;
  X509CertificateStructure? get c {
    if (_c == null) {
        try {
            final Uint8List tbsBytes = _impl.body;
            if (tbsBytes.isNotEmpty) {
              final stream = Asn1Stream(PdfStreamReader(tbsBytes));
                final obj = stream.readAsn1();
                 if (obj is Asn1Sequence) {
                    _c = X509CertificateStructure(obj);
                 }
            }
        } catch (_) {}
    }
    return _c;
  }

  ck.PublicKey get publicKey {
    try {
      final pcKey = _impl.publicKey;
      if (pcKey is pc.RSAPublicKey) {
        return ck.RsaPublicKey(
            modulus: pcKey.modulus!, exponent: pcKey.publicExponent!);
      }
      if (pcKey is pc.ECPublicKey) {
        final String? domainName = pcKey.parameters?.domainName;
        final ck.Identifier curve = _curveFromDomainName(domainName);
        return ck.EcPublicKey(
          xCoordinate: pcKey.Q!.x!.toBigInteger()!,
          yCoordinate: pcKey.Q!.y!.toBigInteger()!,
          curve: curve,
        );
      }
    } catch (_) {}
    throw UnimplementedError('PublicKey conversion not implemented');
  }

  @override
  X509Extensions? getX509Extensions() {
    final exts = _impl.extensions;
    if (exts.isEmpty) return null;

    try {
        final map = <DerObjectID, X509Extension>{};
        final ordering = <DerObjectID>[];
        
        for (final extSeq in exts) {
            final oidStr = (extSeq.elements![0] as pc_asn1.ASN1ObjectIdentifier).objectIdentifierAsString;
            final oid = DerObjectID(oidStr);
            
            bool critical = false;
            Uint8List octets;
            
            if (extSeq.elements!.length == 3) {
                 final val = (extSeq.elements![1] as pc_asn1.ASN1Boolean);
              critical = val.boolValue ?? false;
                octets = (extSeq.elements![2] as pc_asn1.ASN1OctetString).octets!;
            } else {
                 octets = (extSeq.elements![1] as pc_asn1.ASN1OctetString).octets!;
            }
            
            map[oid] = X509Extension(critical, Asn1Octet(octets));
            ordering.add(oid);
        }
        return X509Extensions(map, ordering);
    } catch (_) {
      return null;
    }
  }

  pc.CipherParameters getPublicKey() {
    final key = _impl.publicKey;
    if (key is pc.RSAPublicKey) {
        return pc.PublicKeyParameter<pc.RSAPublicKey>(key);
    } else if (key is pc.ECPublicKey) {
        return pc.PublicKeyParameter<pc.ECPublicKey>(key);
    }
    throw UnimplementedError('Unsupported key type ');
  }

  CipherParameter getPublicKeyParam() {
    try {
      final key = _impl.publicKey;
      if (key is pc.RSAPublicKey) {
        return RsaKeyParam(false, key.modulus, key.publicExponent);
      }
      if (key is pc.ECPublicKey) {
        return EcPublicKeyParam(key);
      }
    } catch (_) {
      // ignore, fall through to SPKI parsing
    }

    final PublicKeyInformation? spki = c?.subjectPublicKeyInfo;
    final List<int>? spkiDer = spki?.getAsn1().getDerEncoded();
    if (spkiDer == null || spkiDer.isEmpty) {
      throw UnimplementedError('Unsupported key type');
    }

    // Try EC from SubjectPublicKeyInfo DER
    try {
      final pc.ECPublicKey ec = CryptoUtils.ecPublicKeyFromDerBytes(
        Uint8List.fromList(spkiDer),
      );
      return EcPublicKeyParam(ec);
    } catch (_) {}

    throw UnimplementedError('Unsupported key type');
  }

  ck.Identifier _curveFromDomainName(String? domainName) {
    switch (domainName) {
      case 'prime256v1':
      case 'secp256r1':
        return ck.curves.p256;
      case 'secp256k1':
        return ck.curves.p256k;
      case 'secp384r1':
        return ck.curves.p384;
      case 'secp521r1':
        return ck.curves.p521;
    }
    return ck.curves.p256;
  }

  List<int>? getTbsCertificate() {
    return _impl.body;
  }

  List<int>? getSignature() {
    return _impl.signatureValue;
  }

  void verify(pc.CipherParameters key) {
    final String sigOid = _impl.signatureAlgorithmOI.objectIdentifierAsString!;

      if (sigOid == '1.2.840.113549.1.1.10') {
        _verifyRsassaPss(key);
        return;
      }

      if (_isEcdsaSignatureOid(sigOid)) {
        _verifyEcdsa(sigOid, key);
        return;
      }

      try {
            if (key is pc.PublicKeyParameter<pc.RSAPublicKey>) {
                final digest = _impl.digestAlgorithm;
                if (!_impl.verifySignature(Uint8List.fromList(getSignature()!), Uint8List.fromList(getTbsCertificate()!), digest)) {
                     throw Exception('Signature verification failed');
                }
                return;
            }
      } catch (e) {
      }
      
      throw UnimplementedError('Signature verification for  not implemented');
  } 
  
  static bool _isEcdsaSignatureOid(String oid) {
    return oid == '1.2.840.10045.4.1' ||
        oid == '1.2.840.10045.4.3.1' ||
        oid == '1.2.840.10045.4.3.2' ||
        oid == '1.2.840.10045.4.3.3' ||
        oid == '1.2.840.10045.4.3.4';
  }

  static pc.Digest _pcDigestForEcdsaSignatureOid(String oid) {
    switch (oid) {
      case '1.2.840.10045.4.1': return pc.SHA1Digest();
      case '1.2.840.10045.4.3.1': return pc.SHA224Digest();
      case '1.2.840.10045.4.3.2': return pc.SHA256Digest();
      case '1.2.840.10045.4.3.3': return pc.SHA384Digest();
      case '1.2.840.10045.4.3.4': return pc.SHA512Digest();
    }
    throw ArgumentError.value(oid, 'oid', 'Unsupported ECDSA signature OID');
  }

  void _verifyEcdsa(String sigOid, pc.CipherParameters publicKey) {
    pc.ECPublicKey ecKey;
    if (publicKey is pc.PublicKeyParameter<pc.ECPublicKey>) {
        ecKey = publicKey.key;
    } else {
         throw ArgumentError('Expected EC public key');
    }

    final List<int>? tbs = getTbsCertificate();
    final List<int>? sigBytes = getSignature();
    if (tbs == null || sigBytes == null) {
      throw Exception('Missing certificate data for signature verification');
    }

    final pc_asn1.ASN1Object parsed =
        pc_asn1.ASN1Parser(Uint8List.fromList(sigBytes)).nextObject();
    if (parsed is! pc_asn1.ASN1Sequence || parsed.elements!.length < 2) {
      throw Exception('Invalid ECDSA signature encoding');
    }
    final pc_asn1.ASN1Object rObj = parsed.elements![0];
    final pc_asn1.ASN1Object sObj = parsed.elements![1];
    if (rObj is! pc_asn1.ASN1Integer || sObj is! pc_asn1.ASN1Integer) {
      throw Exception('Invalid ECDSA signature integers');
    }
    final pc_asn1.ASN1Integer rInt = rObj;
    final pc_asn1.ASN1Integer sInt = sObj;

    final pc.Digest digest = _pcDigestForEcdsaSignatureOid(sigOid);
    final pc.ECDSASigner signer = pc.ECDSASigner(digest); 
    signer.init(
      false,
      pc.PublicKeyParameter<pc.ECPublicKey>(ecKey),
    );

    final bool ok = signer.verifySignature(
      Uint8List.fromList(tbs),
      pc.ECSignature(rInt.integer!, sInt.integer!),
    );
    if (!ok) {
      throw Exception('Public key presented not for certificate signature');
    }
  }

  void _verifyRsassaPss(pc.CipherParameters publicKey) {
      pc.RSAPublicKey rsaKey;
      if (publicKey is pc.PublicKeyParameter<pc.RSAPublicKey>) {
          rsaKey = publicKey.key;
      } else {
          throw ArgumentError('Expected RSA public key');
      }
      
      final List<int>? tbs = getTbsCertificate();
      final List<int>? sigBytes = getSignature();
      final params = _impl.signatureParameters;
      
      final ({String hashOid, String mgfHashOid, int saltLength}) pss =
        _parseRsassaPssParamsBestEffort(params);

    final pc.Digest hashDigest = _pcDigestForOid(pss.hashOid);
    final pc.Digest mgfDigest = _pcDigestForOid(pss.mgfHashOid);

     final pc.SecureRandom random = pc.FortunaRandom()
      ..seed(pc.KeyParameter(Uint8List(32)));
    final pc.PSSSigner signer = pc.PSSSigner(
      pc.RSAEngine(),
      hashDigest,
      mgfDigest,
    );
    signer.init(
      false,
      pc.ParametersWithSaltConfiguration(
        pc.PublicKeyParameter<pc.RSAPublicKey>(rsaKey),
        random,
        pss.saltLength,
      ),
    );

    final bool ok = signer.verifySignature(
      Uint8List.fromList(tbs!),
      pc.PSSSignature(Uint8List.fromList(sigBytes!)),
    );
    if (!ok) {
      throw Exception('Public key presented not for certificate signature');
    }

  }

    static pc.Digest _pcDigestForOid(String oid) {
    switch (oid) {
      case '1.3.14.3.2.26': return pc.SHA1Digest();
      case '2.16.840.1.101.3.4.2.4': return pc.SHA224Digest();
      case '2.16.840.1.101.3.4.2.1': return pc.SHA256Digest();
      case '2.16.840.1.101.3.4.2.2': return pc.SHA384Digest();
      case '2.16.840.1.101.3.4.2.3': return pc.SHA512Digest();
    }
    throw ArgumentError.value(oid, 'oid', 'Unsupported digest OID');
  }

  static ({String hashOid, String mgfHashOid, int saltLength})
      _parseRsassaPssParamsBestEffort(pc_asn1.ASN1Object params) {
    String hashOid = '1.3.14.3.2.26'; 
    String mgfHashOid = '1.3.14.3.2.26'; 
    int saltLen = 20;

    try {
      if (params is! pc_asn1.ASN1Sequence) {
        return (hashOid: hashOid, mgfHashOid: mgfHashOid, saltLength: saltLen);
      }

        for (final pc_asn1.ASN1Object element in params.elements!) {
        final int? tag = element.tag;
        if (tag == null) continue;
        final int tagNo = tag & 0x1f;
        final Uint8List? valueBytes = element.valueBytes;
        if (valueBytes == null || valueBytes.isEmpty) continue;
        final pc_asn1.ASN1Object inner =
          pc_asn1.ASN1Parser(valueBytes).nextObject();

        if (tagNo == 0) {
           if (inner is pc_asn1.ASN1Sequence && inner.elements!.isNotEmpty && inner.elements![0] is pc_asn1.ASN1ObjectIdentifier) {
               hashOid = (inner.elements![0] as pc_asn1.ASN1ObjectIdentifier).objectIdentifierAsString!;
           }
          continue;
        }

        if (tagNo == 1) {
             if (inner is pc_asn1.ASN1Sequence && inner.elements!.isNotEmpty && inner.elements![0] is pc_asn1.ASN1ObjectIdentifier) {
                 if ((inner.elements![0] as pc_asn1.ASN1ObjectIdentifier).objectIdentifierAsString == '1.2.840.113549.1.1.8') {
                      final mgfParams = inner.elements![1];
                       if (mgfParams is pc_asn1.ASN1Sequence && mgfParams.elements!.isNotEmpty && mgfParams.elements![0] is pc_asn1.ASN1ObjectIdentifier) {
                           mgfHashOid = (mgfParams.elements![0] as pc_asn1.ASN1ObjectIdentifier).objectIdentifierAsString!;
                       }
                 }
             }
          continue;
        }

        if (tagNo == 2 && inner is pc_asn1.ASN1Integer) {
          saltLen = inner.integer!.toInt();
          continue;
        }
      }
    } catch (_) {
      hashOid = '2.16.840.1.101.3.4.2.1'; 
      mgfHashOid = hashOid;
      saltLen = 32;
    }

    return (hashOid: hashOid, mgfHashOid: mgfHashOid, saltLength: saltLen);
  }

  void checkSignature(pc.CipherParameters publicKey, pc.Signer signature) {
    // Basic compatibility helper
    // Legacy signatures might need specific update logic not supported directly by new Signer interface
    try {
        signature.init(false, publicKey);
        // Assuming verifySignature(message, signature) for new interface
        final List<int>? b = getTbsCertificate();
        final List<int>? sig = getSignature();
        if (b != null && sig != null) {
            // This is speculative. If Signer expects 2 arguments:
            // signature.verifySignature(Uint8List.fromList(b), pc.Signature(Uint8List.fromList(sig)));
            // We can't know for sure here.
            throw UnimplementedError("CheckSignature compatibility is limited. Refactor caller to use X509Certificate.verify()");
        }
    } catch(e) {
        throw e;
    }
  }

}

class X509CertificateParser {
   X509CertificateParser();
   
   X509Certificate? readCertificate(PdfStreamReader inStream) {
       try {
           final stream = Asn1Stream(inStream);
           final asn1Obj = stream.readAsn1();
           if (asn1Obj == null) return null;
           
         final List<int>? der = asn1Obj.getDerEncoded();
         if (der == null || der.isEmpty) return null;
         final x509 = X509.fromDer(Uint8List.fromList(der));
           return X509Certificate(x509);
           
       } catch(e) {
           return null;
       }
   }
   
    List<X509Certificate?>? getCertificateChain(PdfStreamReader inStream) {
        try {
            final stream = Asn1Stream(inStream);
            final asn1Obj = stream.readAsn1();
            if (asn1Obj == null) return null;
            
        final List<int>? der = asn1Obj.getDerEncoded();
        if (der == null || der.isEmpty) return null;
        final x509 = X509.fromDer(Uint8List.fromList(der));
            return [X509Certificate(x509)];
        } catch (_) {
            return null;
        }
    }
}

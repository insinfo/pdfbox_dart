import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../io/stream_reader.dart';
import '../../crypto/asn1/core/legacy_asn1.dart';
import '../../crypto/asn1/core/legacy_asn1_stream.dart';
import '../../crypto/asn1/core/legacy_der.dart';
import '../../crypto/cryptography/cipher_block_chaining_mode.dart';
import '../../crypto/cryptography/cipher_utils.dart';
import '../../crypto/cryptography/ipadding.dart';
import '../../crypto/cryptography/pkcs1_encoding.dart';
import '../../crypto/cryptography/rsa_algorithm.dart';
import 'pkcs/pfx_data.dart';

/// Minimal OID constants used by the signature helpers.
class NistObjectIds {
  static DerObjectID sha256 = DerObjectID('2.16.840.1.101.3.4.2.1');
  static DerObjectID sha384 = DerObjectID('2.16.840.1.101.3.4.2.2');
  static DerObjectID sha512 = DerObjectID('2.16.840.1.101.3.4.2.3');
  static DerObjectID ripeMD160 = DerObjectID('1.3.36.3.2.1');
  static DerObjectID dsaWithSHA256 = DerObjectID('2.16.840.1.101.3.4.3.2');
  static DerObjectID rsaSignatureWithRipeMD160 = DerObjectID('1.3.36.3.3.1.2');
}

/// Minimal signer factory used by CMS validation helpers.
class SignerUtilities {
  SignerUtilities() {
    _algms['MD2WITHRSA'] = 'MD2withRSA';
    _algms['MD2WITHRSAENCRYPTION'] = 'MD2withRSA';
    _algms[PkcsObjectId.md2WithRsaEncryption.id] = 'MD2withRSA';
    _algms[PkcsObjectId.rsaEncryption.id] = 'RSA';
    _algms['SHA1WITHRSA'] = 'SHA-1withRSA';
    _algms['SHA1WITHRSAENCRYPTION'] = 'SHA-1withRSA';
    _algms[PkcsObjectId.sha1WithRsaEncryption.id] = 'SHA-1withRSA';
    _algms['SHA-1WITHRSA'] = 'SHA-1withRSA';
    _algms['SHA256WITHRSA'] = 'SHA-256withRSA';
    _algms['SHA256WITHRSAENCRYPTION'] = 'SHA-256withRSA';
    _algms[PkcsObjectId.sha256WithRsaEncryption.id] = 'SHA-256withRSA';
    _algms['SHA-256WITHRSA'] = 'SHA-256withRSA';
    _algms['SHA1WITHRSAANDMGF1'] = 'SHA-1withRSAandMGF1';
    _algms['SHA-1WITHRSAANDMGF1'] = 'SHA-1withRSAandMGF1';
    _algms['SHA1WITHRSA/PSS'] = 'SHA-1withRSAandMGF1';
    _algms['SHA-1WITHRSA/PSS'] = 'SHA-1withRSAandMGF1';
    _algms['SHA224WITHRSAANDMGF1'] = 'SHA-224withRSAandMGF1';
    _algms['SHA-224WITHRSAANDMGF1'] = 'SHA-224withRSAandMGF1';
    _algms['SHA224WITHRSA/PSS'] = 'SHA-224withRSAandMGF1';
    _algms['SHA-224WITHRSA/PSS'] = 'SHA-224withRSAandMGF1';
    _algms['SHA256WITHRSAANDMGF1'] = 'SHA-256withRSAandMGF1';
    _algms['SHA-256WITHRSAANDMGF1'] = 'SHA-256withRSAandMGF1';
    _algms['SHA256WITHRSA/PSS'] = 'SHA-256withRSAandMGF1';
    _algms['SHA-256WITHRSA/PSS'] = 'SHA-256withRSAandMGF1';
    _algms['SHA384WITHRSA'] = 'SHA-384withRSA';
    _algms['SHA512WITHRSA'] = 'SHA-512withRSA';
    _algms['SHA384WITHRSAENCRYPTION'] = 'SHA-384withRSA';
    _algms[PkcsObjectId.sha384WithRsaEncryption.id] = 'SHA-384withRSA';
    _algms['SHA-384WITHRSA'] = 'SHA-384withRSA';
    _algms['SHA-512WITHRSA'] = 'SHA-512withRSA';
    _algms['SHA512WITHRSAENCRYPTION'] = 'SHA-512withRSA';
    _algms['SHA-512WITHRSAENCRYPTION'] = 'SHA-512withRSA';
    _algms[PkcsObjectId.sha512WithRsaEncryption.id] = 'SHA-512withRSA';
    _algms['SHA384WITHRSAANDMGF1'] = 'SHA-384withRSAandMGF1';
    _algms['SHA-384WITHRSAANDMGF1'] = 'SHA-384withRSAandMGF1';
    _algms['SHA384WITHRSA/PSS'] = 'SHA-384withRSAandMGF1';
    _algms['SHA-384WITHRSA/PSS'] = 'SHA-384withRSAandMGF1';
    _algms['SHA512WITHRSAANDMGF1'] = 'SHA-512withRSAandMGF1';
    _algms['SHA-512WITHRSAANDMGF1'] = 'SHA-512withRSAandMGF1';
    _algms['SHA512WITHRSA/PSS'] = 'SHA-512withRSAandMGF1';
    _algms['SHA-512WITHRSA/PSS'] = 'SHA-512withRSAandMGF1';
    _algms['DSAWITHSHA256'] = 'SHA-256withDSA';
    _algms['DSAWITHSHA-256'] = 'SHA-256withDSA';
    _algms['SHA256/DSA'] = 'SHA-256withDSA';
    _algms['SHA-256/DSA'] = 'SHA-256withDSA';
    _algms['SHA256WITHDSA'] = 'SHA-256withDSA';
    _algms['SHA-256WITHDSA'] = 'SHA-256withDSA';
    _algms[NistObjectIds.dsaWithSHA256.id] = 'SHA-256withDSA';
    _algms['RIPEMD160WITHRSA'] = 'RIPEMD160withRSA';
    _algms['RIPEMD160WITHRSAENCRYPTION'] = 'RIPEMD160withRSA';
    _algms[NistObjectIds.rsaSignatureWithRipeMD160.id] = 'RIPEMD160withRSA';

    _algms['SHA1WITHECDSA'] = 'SHA-1withECDSA';
    _algms['SHA-1WITHECDSA'] = 'SHA-1withECDSA';
    _algms['SHA256WITHECDSA'] = 'SHA-256withECDSA';
    _algms['SHA-256WITHECDSA'] = 'SHA-256withECDSA';
    _algms['SHA384WITHECDSA'] = 'SHA-384withECDSA';
    _algms['SHA-384WITHECDSA'] = 'SHA-384withECDSA';
    _algms['SHA512WITHECDSA'] = 'SHA-512withECDSA';
    _algms['SHA-512WITHECDSA'] = 'SHA-512withECDSA';
    _algms['1.2.840.10045.4.1'] = 'SHA-1withECDSA';
    _algms['1.2.840.10045.4.3.2'] = 'SHA-256withECDSA';
    _algms['1.2.840.10045.4.3.3'] = 'SHA-384withECDSA';
    _algms['1.2.840.10045.4.3.4'] = 'SHA-512withECDSA';

    _oids['SHA-1withRSA'] = PkcsObjectId.sha1WithRsaEncryption;
    _oids['SHA-256withRSA'] = PkcsObjectId.sha256WithRsaEncryption;
    _oids['SHA-384withRSA'] = PkcsObjectId.sha384WithRsaEncryption;
    _oids['SHA-512withRSA'] = PkcsObjectId.sha512WithRsaEncryption;
    _oids['RIPEMD160withRSA'] = NistObjectIds.rsaSignatureWithRipeMD160;
  }

  final Map<String?, String> _algms = <String?, String>{};
  final Map<String, DerObjectID> _oids = <String, DerObjectID>{};

  ISigner getSigner(String algorithm) {
    final String lower = algorithm.toLowerCase();
    String? mechanism = algorithm;
    _algms.forEach((String? key, String value) {
      if (mechanism == algorithm && key != null && key.toLowerCase() == lower) {
        mechanism = value;
      }
    });
    if (mechanism == 'SHA-1withRSA') {
      return _RmdSigner(DigestAlgorithms.sha1);
    } else if (mechanism == 'SHA-256withRSA') {
      return _RmdSigner(DigestAlgorithms.sha256);
    } else if (mechanism == 'SHA-384withRSA') {
      return _RmdSigner(DigestAlgorithms.sha384);
    } else if (mechanism == 'SHA-512withRSA') {
      return _RmdSigner(DigestAlgorithms.sha512);
    } else if (mechanism == 'SHA-1withECDSA') {
      return _EcdsaSigner(DigestAlgorithms.sha1);
    } else if (mechanism == 'SHA-256withECDSA') {
      return _EcdsaSigner(DigestAlgorithms.sha256);
    } else if (mechanism == 'SHA-384withECDSA') {
      return _EcdsaSigner(DigestAlgorithms.sha384);
    } else if (mechanism == 'SHA-512withECDSA') {
      return _EcdsaSigner(DigestAlgorithms.sha512);
    }
    throw ArgumentError.value('Signer $algorithm not recognised.');
  }
}

class _RmdSigner implements ISigner {
  _RmdSigner(String digest) {
    _digest = _getDigest(digest);
    _rsaEngine = Pkcs1Encoding(RsaAlgorithm());
    _id = Algorithms(_digestMap[digest], DerNull.value);
    reset();
  }

  Map<String, DerObjectID>? _digestMapCache;
  late ICipherBlock _rsaEngine;
  Algorithms? _id;
  late Hash _digest;
  late BytesBuilder _buffer;
  late bool _isSigning;

  Map<String, DerObjectID> get _digestMap {
    if (_digestMapCache == null) {
      _digestMapCache = <String, DerObjectID>{};
      _digestMapCache![DigestAlgorithms.sha1] = X509Objects.idSha1;
      _digestMapCache![DigestAlgorithms.sha256] = NistObjectIds.sha256;
      _digestMapCache![DigestAlgorithms.sha384] = NistObjectIds.sha384;
      _digestMapCache![DigestAlgorithms.sha512] = NistObjectIds.sha512;
    }
    return _digestMapCache!;
  }

  Hash _getDigest(String digest) {
    if (digest == DigestAlgorithms.sha1) return sha1;
    if (digest == DigestAlgorithms.sha256) return sha256;
    if (digest == DigestAlgorithms.sha384) return sha384;
    if (digest == DigestAlgorithms.sha512) return sha512;
    throw ArgumentError.value(digest, 'digest', 'Invalid digest');
  }

  @override
  void initialize(bool isSigning, ICipherParameter? parameters) {
    _isSigning = isSigning;
    final CipherParameter? k = parameters as CipherParameter?;
    if (isSigning && k != null && !(k.isPrivate ?? false)) {
      throw ArgumentError.value('Private key required.');
    }
    if (!isSigning && k != null && (k.isPrivate ?? false)) {
      throw ArgumentError.value('Public key required.');
    }
    reset();
    _rsaEngine.initialize(isSigning, parameters);
  }

  @override
  void blockUpdate(List<int> input, int inOff, int length) {
    _buffer.add(input.sublist(inOff, inOff + length));
  }

  @override
  List<int>? generateSignature() {
    if (!_isSigning) {
      throw ArgumentError.value('Invalid entry');
    }
    final Digest digest = _digest.convert(_buffer.toBytes());
    final List<int> hash = digest.bytes;
    final List<int> data = _derEncode(hash)!;
    return _rsaEngine.processBlock(data, 0, data.length);
  }

  @override
  bool validateSignature(List<int> signature) {
    if (_isSigning) {
      throw Exception('Invalid entry');
    }
    final Digest digest = _digest.convert(_buffer.toBytes());
    final List<int> hash = digest.bytes;
    List<int> sig;
    List<int> expected;
    try {
      sig = _rsaEngine.processBlock(signature, 0, signature.length)!;
      expected = _derEncode(hash)!;
    } catch (e) {
      return false;
    }

    try {
      if (_id != null && _id!.id != null) {
        final Asn1? parsed = Asn1Stream(PdfStreamReader(sig)).readAsn1();
        if (parsed is Asn1Sequence && parsed.count >= 2) {
          final Asn1Sequence algSeq = parsed[0]!.getAsn1()! as Asn1Sequence;
          final DerObjectID oid = algSeq[0]!.getAsn1()! as DerObjectID;
          final Asn1? digestObj = parsed[1]!.getAsn1();
          if (digestObj is DerOctet) {
            final List<int> digestBytes = digestObj.getOctets() ?? const <int>[];
            if (oid.id == _id!.id!.id && digestBytes.length == hash.length) {
              bool ok = true;
              for (int i = 0; i < hash.length; i++) {
                if (digestBytes[i] != hash[i]) {
                  ok = false;
                  break;
                }
              }
              if (ok) {
                return true;
              }
            }
          }
        }
      }
    } catch (_) {
      // fall back to strict compare below
    }

    bool matches(List<int> expectedBytes) {
      if (sig.length == expectedBytes.length) {
        for (int i = 0; i < sig.length; i++) {
          if (sig[i] != expectedBytes[i]) {
            return false;
          }
        }
        return true;
      }
      if (sig.length == expectedBytes.length - 2) {
        final int sigOffset = sig.length - hash.length - 2;
        final int expectedOffset = expectedBytes.length - hash.length - 2;
        final List<int> expectedAdjusted = List<int>.from(expectedBytes);
        expectedAdjusted[1] -= 2;
        expectedAdjusted[3] -= 2;
        for (int i = 0; i < hash.length; i++) {
          if (sig[sigOffset + i] != expectedAdjusted[expectedOffset + i]) {
            return false;
          }
        }
        for (int i = 0; i < sigOffset; i++) {
          if (sig[i] != expectedAdjusted[i]) {
            return false;
          }
        }
        return true;
      }
      return false;
    }

    if (matches(expected)) {
      return true;
    }
    if (_id != null && _id!.id != null) {
      final List<int>? expectedNoParams =
          DigestInformation(Algorithms(_id!.id!), hash).getDerEncoded();
      if (expectedNoParams != null && matches(expectedNoParams)) {
        return true;
      }
    }
    return false;
  }

  List<int>? _derEncode(List<int>? hash) {
    if (_id == null) {
      return hash;
    }
    return DigestInformation(_id, hash).getDerEncoded();
  }

  @override
  void reset() {
    _buffer = BytesBuilder(copy: true);
  }
}

class _EcdsaSigner implements ISigner {
  _EcdsaSigner(String digest) {
    _digestName = digest;
    reset();
  }

  late final String _digestName;
  late bool _isSigning;
  EcPrivateKeyParam? _privateKey;
  EcPublicKeyParam? _publicKey;
  late BytesBuilder _buffer;

  Hash _hashForName(String digest) {
    if (digest == DigestAlgorithms.sha1) return sha1;
    if (digest == DigestAlgorithms.sha256) return sha256;
    if (digest == DigestAlgorithms.sha384) return sha384;
    if (digest == DigestAlgorithms.sha512) return sha512;
    throw ArgumentError.value(digest, 'digest', 'Invalid digest');
  }

  pc.SecureRandom _secureRandom() {
    final pc.FortunaRandom rnd = pc.FortunaRandom();
    final Random sys = Random.secure();
    final Uint8List seed = Uint8List.fromList(
      List<int>.generate(32, (_) => sys.nextInt(256)),
    );
    rnd.seed(pc.KeyParameter(seed));
    return rnd;
  }

  @override
  void initialize(bool isSigning, ICipherParameter? parameters) {
    _isSigning = isSigning;
    reset();

    if (isSigning) {
      if (parameters is! EcPrivateKeyParam) {
        throw ArgumentError.value(parameters, 'parameters', 'EC private key required.');
      }
      if (!(parameters.isPrivate ?? false)) {
        throw ArgumentError.value(parameters, 'parameters', 'Private key required.');
      }
      _privateKey = parameters;
      _publicKey = null;
      return;
    }

    if (parameters is! EcPublicKeyParam) {
      throw ArgumentError.value(parameters, 'parameters', 'EC public key required.');
    }
    if (parameters.isPrivate ?? false) {
      throw ArgumentError.value(parameters, 'parameters', 'Public key required.');
    }
    _publicKey = parameters;
    _privateKey = null;
  }

  @override
  void blockUpdate(List<int> input, int inOff, int length) {
    _buffer.add(input.sublist(inOff, inOff + length));
  }

  Uint8List _hash() {
    final Hash h = _hashForName(_digestName);
    final Digest d = h.convert(_buffer.toBytes());
    return Uint8List.fromList(d.bytes);
  }

  List<int> _derEncodeSig(pc.ECSignature sig) {
    final DerSequence seq = DerSequence(
      array: <Asn1Encode>[
        DerInteger.fromNumber(sig.r),
        DerInteger.fromNumber(sig.s),
      ],
    );
    return seq.getEncoded(Asn1.der) ?? const <int>[];
  }

  pc.ECSignature _derDecodeSig(List<int> signature) {
    final Asn1? parsed = Asn1Stream(PdfStreamReader(signature)).readAsn1();
    if (parsed is! Asn1Sequence || parsed.count < 2) {
      throw ArgumentError('Invalid ECDSA signature encoding.');
    }
    final DerInteger r = DerInteger.getNumber(parsed[0])!;
    final DerInteger s = DerInteger.getNumber(parsed[1])!;
    return pc.ECSignature(r.positiveValue, s.positiveValue);
  }

  @override
  List<int>? generateSignature() {
    if (!_isSigning) {
      throw ArgumentError.value('Invalid entry');
    }
    final EcPrivateKeyParam? k = _privateKey;
    if (k == null) {
      throw StateError('Missing EC private key');
    }

    final Uint8List hashBytes = _hash();
    final pc.ECDSASigner signer = pc.ECDSASigner();
    signer.init(
      true,
      pc.ParametersWithRandom(
        pc.PrivateKeyParameter<pc.ECPrivateKey>(k.privateKey),
        _secureRandom(),
      ),
    );
    final pc.ECSignature sig = signer.generateSignature(hashBytes) as pc.ECSignature;
    final List<int> der = _derEncodeSig(sig);
    if (der.isEmpty) {
      throw StateError('Failed to DER-encode ECDSA signature');
    }
    return der;
  }

  @override
  bool validateSignature(List<int> signature) {
    if (_isSigning) {
      throw Exception('Invalid entry');
    }
    final EcPublicKeyParam? k = _publicKey;
    if (k == null) {
      return false;
    }

    final Uint8List hashBytes = _hash();

    pc.ECSignature sig;
    try {
      sig = _derDecodeSig(signature);
    } catch (_) {
      return false;
    }

    final pc.ECDSASigner signer = pc.ECDSASigner();
    signer.init(
      false,
      pc.PublicKeyParameter<pc.ECPublicKey>(k.publicKey),
    );

    try {
      return signer.verifySignature(hashBytes, sig);
    } catch (_) {
      return false;
    }
  }

  @override
  void reset() {
    _buffer = BytesBuilder(copy: true);
  }
}



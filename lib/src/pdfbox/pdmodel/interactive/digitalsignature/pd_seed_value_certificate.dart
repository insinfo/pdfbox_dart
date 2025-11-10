import 'dart:typed_data';

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_string.dart';

/// Represents certificate constraints within a signature seed value dictionary.
class PDSeedValueCertificate implements COSObjectable {
  PDSeedValueCertificate([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary() {
    if (dictionary != null) {
      _dictionary.isDirect = true;
    }
  }

  /// Flag indicating that the subject constraint must be enforced.
  static const int flagSubject = 1;

  /// Flag indicating that the issuer constraint must be enforced.
  static const int flagIssuer = 1 << 1;

  /// Flag indicating that the OID constraint must be enforced.
  static const int flagOid = 1 << 2;

  /// Flag indicating that the subject DN constraint must be enforced.
  static const int flagSubjectDn = 1 << 3;

  /// Flag indicating that the key usage constraint must be enforced.
  static const int flagKeyUsage = 1 << 5;

  /// Flag indicating that a URL constraint must be enforced.
  static const int flagUrl = 1 << 6;

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  bool isSubjectRequired() => _dictionary.getFlag(COSName.ff, flagSubject);

  void setSubjectRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagSubject, value);

  bool isIssuerRequired() => _dictionary.getFlag(COSName.ff, flagIssuer);

  void setIssuerRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagIssuer, value);

  bool isOIDRequired() => _dictionary.getFlag(COSName.ff, flagOid);

  void setOIDRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagOid, value);

  bool isSubjectDNRequired() =>
      _dictionary.getFlag(COSName.ff, flagSubjectDn);

  void setSubjectDNRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagSubjectDn, value);

  bool isKeyUsageRequired() =>
      _dictionary.getFlag(COSName.ff, flagKeyUsage);

  void setKeyUsageRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagKeyUsage, value);

  bool isURLRequired() => _dictionary.getFlag(COSName.ff, flagUrl);

  void setURLRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagUrl, value);

  List<Uint8List>? getSubject() {
    final array = _dictionary.getCOSArray(COSName.subject);
    return array?.toUint8List();
  }

  void setSubject(List<Uint8List>? subjects) {
    if (subjects == null || subjects.isEmpty) {
      _dictionary.removeItem(COSName.subject);
      return;
    }
    _dictionary.setItem(COSName.subject, _toCOSArray(subjects));
  }

  void addSubject(Uint8List subject) {
    final array = _dictionary.getCOSArray(COSName.subject) ?? COSArray();
    array.addObject(_toCOSString(subject));
    _dictionary.setItem(COSName.subject, array);
  }

  void removeSubject(Uint8List subject) {
    final array = _dictionary.getCOSArray(COSName.subject);
    if (array != null) {
      array.remove(_toCOSString(subject));
      if (array.isEmpty) {
        _dictionary.removeItem(COSName.subject);
      }
    }
  }

  List<Map<String, String>>? getSubjectDN() {
    final cosArray = _dictionary.getCOSArray(COSName.subjectDn);
    if (cosArray == null) {
      return null;
    }
    final result = <Map<String, String>>[];
    for (final item in cosArray) {
      if (item is COSDictionary) {
        final entryMap = <String, String>{};
        for (final entry in item.entries) {
          final value = item.getString(entry.key);
          if (value != null) {
            entryMap[entry.key.name] = value;
          }
        }
        result.add(entryMap);
      }
    }
    return result;
  }

  void setSubjectDN(List<Map<String, String>>? subjectDN) {
    if (subjectDN == null || subjectDN.isEmpty) {
      _dictionary.removeItem(COSName.subjectDn);
      return;
    }
    final dictionaries = subjectDN.map((value) {
      final dict = COSDictionary();
      value.forEach((key, entryValue) {
        dict.setString(COSName(key), entryValue);
      });
      return dict;
    });
    _dictionary.setItem(COSName.subjectDn, COSArray(dictionaries));
  }

  List<String>? getKeyUsage() {
    final array = _dictionary.getCOSArray(COSName.keyUsage);
    if (array == null) {
      return null;
    }
    final usages = <String>[];
    for (final item in array) {
      if (item is COSString) {
        usages.add(item.string);
      }
    }
    return usages;
  }

  void setKeyUsage(List<String>? keyUsageExtensions) {
    if (keyUsageExtensions == null || keyUsageExtensions.isEmpty) {
      _dictionary.removeItem(COSName.keyUsage);
      return;
    }
    _dictionary
        .setItem(COSName.keyUsage, COSArray.ofCOSStrings(keyUsageExtensions));
  }

  void addKeyUsage(String keyUsageExtension) {
    _validateKeyUsagePattern(keyUsageExtension);
    final array = _dictionary.getCOSArray(COSName.keyUsage) ?? COSArray();
    array.addObject(COSString(keyUsageExtension));
    _dictionary.setItem(COSName.keyUsage, array);
  }

  void addKeyUsageFlags({
    required String digitalSignature,
    required String nonRepudiation,
    required String keyEncipherment,
    required String dataEncipherment,
    required String keyAgreement,
    required String keyCertSign,
    required String cRLSign,
    required String encipherOnly,
    required String decipherOnly,
  }) {
    final flags = <String>[
      digitalSignature,
      nonRepudiation,
      keyEncipherment,
      dataEncipherment,
      keyAgreement,
      keyCertSign,
      cRLSign,
      encipherOnly,
      decipherOnly,
    ];
    final buffer = StringBuffer();
    for (final flag in flags) {
      if (flag.length != 1) {
        throw ArgumentError('Flag values must be single-character strings.');
      }
      buffer.write(flag);
    }
    addKeyUsage(buffer.toString());
  }

  void removeKeyUsage(String keyUsageExtension) {
    final array = _dictionary.getCOSArray(COSName.keyUsage);
    if (array != null) {
      array.remove(COSString(keyUsageExtension));
      if (array.isEmpty) {
        _dictionary.removeItem(COSName.keyUsage);
      }
    }
  }

  List<Uint8List>? getIssuer() {
    final array = _dictionary.getCOSArray(COSName.issuer);
    return array?.toUint8List();
  }

  void setIssuer(List<Uint8List>? issuers) {
    if (issuers == null || issuers.isEmpty) {
      _dictionary.removeItem(COSName.issuer);
      return;
    }
    _dictionary.setItem(COSName.issuer, _toCOSArray(issuers));
  }

  void addIssuer(Uint8List issuer) {
    final array = _dictionary.getCOSArray(COSName.issuer) ?? COSArray();
    array.addObject(_toCOSString(issuer));
    _dictionary.setItem(COSName.issuer, array);
  }

  void removeIssuer(Uint8List issuer) {
    final array = _dictionary.getCOSArray(COSName.issuer);
    if (array != null) {
      array.remove(_toCOSString(issuer));
      if (array.isEmpty) {
        _dictionary.removeItem(COSName.issuer);
      }
    }
  }

  List<Uint8List>? getOID() {
    final array = _dictionary.getCOSArray(COSName.oid);
    return array?.toUint8List();
  }

  void setOID(List<Uint8List>? oidByteStrings) {
    if (oidByteStrings == null || oidByteStrings.isEmpty) {
      _dictionary.removeItem(COSName.oid);
      return;
    }
    _dictionary.setItem(COSName.oid, _toCOSArray(oidByteStrings));
  }

  void addOID(Uint8List oid) {
    final array = _dictionary.getCOSArray(COSName.oid) ?? COSArray();
    array.addObject(_toCOSString(oid));
    _dictionary.setItem(COSName.oid, array);
  }

  void removeOID(Uint8List oid) {
    final array = _dictionary.getCOSArray(COSName.oid);
    if (array != null) {
      array.remove(_toCOSString(oid));
      if (array.isEmpty) {
        _dictionary.removeItem(COSName.oid);
      }
    }
  }

  String? getURL() => _dictionary.getString(COSName.url);

  void setURL(String? url) => _dictionary.setString(COSName.url, url);

  String? getURLType() => _dictionary.getNameAsString(COSName.urlType);

  void setURLType(String? urlType) =>
      _dictionary.setName(COSName.urlType, urlType);

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict.setItem(COSName.type, COSName.svCert);
    dict.isDirect = true;
    return dict;
  }

  static COSString _toCOSString(Uint8List value) =>
      COSString.fromBytes(Uint8List.fromList(value));

  static COSArray _toCOSArray(Iterable<Uint8List> values) {
    final array = COSArray();
    for (final value in values) {
      array.addObject(_toCOSString(value));
    }
    return array;
  }

  static void _validateKeyUsagePattern(String pattern) {
    const allowed = '01X';
    for (var i = 0; i < pattern.length; i++) {
      if (!allowed.contains(pattern[i])) {
        throw ArgumentError('Characters can only be 0, 1, or X');
      }
    }
  }
}

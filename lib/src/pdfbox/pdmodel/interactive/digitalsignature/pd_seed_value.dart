import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import 'pd_seed_value_certificate.dart';
import 'pd_seed_value_mdp.dart';
import 'pd_seed_value_time_stamp.dart';

/// Represents a signature seed value dictionary (SV) that constrains how fields
/// should be signed.
class PDSeedValue implements COSObjectable {
  PDSeedValue([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary() {
    if (dictionary != null) {
      _dictionary.isDirect = true;
    }
  }

  static final Set<String> _allowedDigestNames = <String>{
    COSName.digestSha1.name,
    COSName.digestSha256.name,
    COSName.digestSha384.name,
    COSName.digestSha512.name,
    COSName.digestRipemd160.name,
  };

  /// Flag indicating that a specific filter is required.
  static const int flagFilter = 1;

  /// Flag indicating that a specific subfilter is required.
  static const int flagSubFilter = 1 << 1;

  /// Flag indicating that the minimum parser version is required.
  static const int flagV = 1 << 2;

  /// Flag indicating that a specific reason is required.
  static const int flagReason = 1 << 3;

  /// Flag indicating that a legal attestation is required.
  static const int flagLegalAttestation = 1 << 4;

  /// Flag indicating that revocation information is required.
  static const int flagAddRevInfo = 1 << 5;

  /// Flag indicating that a particular digest method is required.
  static const int flagDigestMethod = 1 << 6;

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  bool isFilterRequired() => _dictionary.getFlag(COSName.ff, flagFilter);

  void setFilterRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagFilter, value);

  bool isSubFilterRequired() =>
      _dictionary.getFlag(COSName.ff, flagSubFilter);

  void setSubFilterRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagSubFilter, value);

  bool isDigestMethodRequired() =>
      _dictionary.getFlag(COSName.ff, flagDigestMethod);

  void setDigestMethodRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagDigestMethod, value);

  bool isVRequired() => _dictionary.getFlag(COSName.ff, flagV);

  void setVRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagV, value);

  bool isReasonRequired() =>
      _dictionary.getFlag(COSName.ff, flagReason);

  void setReasonRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagReason, value);

  bool isLegalAttestationRequired() =>
      _dictionary.getFlag(COSName.ff, flagLegalAttestation);

  void setLegalAttestationRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagLegalAttestation, value);

  bool isAddRevInfoRequired() =>
      _dictionary.getFlag(COSName.ff, flagAddRevInfo);

  void setAddRevInfoRequired(bool value) =>
      _dictionary.setFlag(COSName.ff, flagAddRevInfo, value);

  String? getFilter() => _dictionary.getNameAsString(COSName.filter);

  void setFilter(COSName? filter) =>
      _dictionary.setItem(COSName.filter, filter);

  List<String> getSubFilter() {
    final array = _dictionary.getCOSArray(COSName.subFilter);
    return array == null
        ? const <String>[]
        : List.unmodifiable(array.toCOSNameStringList());
  }

  void setSubFilter(List<String>? subFilter) {
    if (subFilter == null || subFilter.isEmpty) {
      _dictionary.removeItem(COSName.subFilter);
      return;
    }
    _dictionary.setItem(COSName.subFilter, COSArray.ofCOSNames(subFilter));
  }

  List<String> getDigestMethod() {
    final array = _dictionary.getCOSArray(COSName.digestMethod);
    return array == null
        ? const <String>[]
        : List.unmodifiable(array.toCOSNameStringList());
  }

  void setDigestMethod(List<String>? digestMethod) {
    if (digestMethod == null || digestMethod.isEmpty) {
      _dictionary.removeItem(COSName.digestMethod);
      return;
    }
    for (final name in digestMethod) {
      if (!_allowedDigestNames.contains(name)) {
        throw ArgumentError('Specified digest $name is not allowed.');
      }
    }
    _dictionary
        .setItem(COSName.digestMethod, COSArray.ofCOSNames(digestMethod));
  }

  double getV() => _dictionary.getFloat(COSName.v) ?? 0;

  void setV(double minimumRequiredCapability) =>
      _dictionary.setFloat(COSName.v, minimumRequiredCapability);

  List<String> getReasons() {
    final array = _dictionary.getCOSArray(COSName.reasons);
    return array == null
        ? const <String>[]
        : List.unmodifiable(array.toCOSNameStringList());
  }

  void setReasons(List<String>? reasons) {
    if (reasons == null || reasons.isEmpty) {
      _dictionary.removeItem(COSName.reasons);
      return;
    }
    _dictionary.setItem(COSName.reasons, COSArray.ofCOSStrings(reasons));
  }

  PDSeedValueMDP? getMDP() {
    final dict = _dictionary.getCOSDictionary(COSName.mdp);
    return dict != null ? PDSeedValueMDP(dict) : null;
  }

  void setMPD(PDSeedValueMDP? mdp) {
    if (mdp == null) {
      _dictionary.removeItem(COSName.mdp);
    } else {
      _dictionary.setItem(COSName.mdp, mdp);
    }
  }

  /// Convenience alias mirroring the Adobe API naming (DocMDP).
  void setMDP(PDSeedValueMDP? mdp) => setMPD(mdp);

  PDSeedValueCertificate? getSeedValueCertificate() {
    final dict = _dictionary.getCOSDictionary(COSName.cert);
    return dict != null ? PDSeedValueCertificate(dict) : null;
  }

  void setSeedValueCertificate(PDSeedValueCertificate? certificate) {
    if (certificate == null) {
      _dictionary.removeItem(COSName.cert);
    } else {
      _dictionary.setItem(COSName.cert, certificate);
    }
  }

  PDSeedValueTimeStamp? getTimeStamp() {
    final dict = _dictionary.getCOSDictionary(COSName.timeStamp);
    return dict != null ? PDSeedValueTimeStamp(dict) : null;
  }

  void setTimeStamp(PDSeedValueTimeStamp? timestamp) {
    if (timestamp == null) {
      _dictionary.removeItem(COSName.timeStamp);
    } else {
      _dictionary.setItem(COSName.timeStamp, timestamp);
    }
  }

  List<String> getLegalAttestation() {
    final array = _dictionary.getCOSArray(COSName.legalAttestation);
    return array == null
        ? const <String>[]
        : List.unmodifiable(array.toCOSNameStringList());
  }

  void setLegalAttestation(List<String>? legalAttestation) {
    if (legalAttestation == null || legalAttestation.isEmpty) {
      _dictionary.removeItem(COSName.legalAttestation);
      return;
    }
    _dictionary.setItem(
      COSName.legalAttestation,
      COSArray.ofCOSStrings(legalAttestation),
    );
  }

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict.setItem(COSName.type, COSName.sv);
    dict.isDirect = true;
    return dict;
  }
}

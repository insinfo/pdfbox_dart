///
/// Model that represents a verified mark certificate data
///
class VmcData {
  /// The base64 encoded logo
  String? base64Logo;

  /// The logo type
  String? type;

  /// The hash
  String? hash;

  /// The readable version of the algorithm of the hash
  String? hashAlgorithmReadable;

  /// The algorithm of the hash
  String? hashAlgorithm;

  VmcData({
    this.base64Logo,
    this.hash,
    this.hashAlgorithm,
    this.hashAlgorithmReadable,
    this.type,
  });

  ///
  ///Json to VmcData object
  ///
  factory VmcData.fromJson(Map<String, dynamic> json) {
    return VmcData(
      base64Logo: json['base64Logo'] as String?,
      hash: json['hash'] as String?,
      hashAlgorithm: json['hashAlgorithm'] as String?,
      hashAlgorithmReadable: json['hashAlgorithmReadable'] as String?,
      type: json['type'] as String?,
    );
  }

  ///
  /// VmcData object to json
  ///
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('base64Logo', base64Logo);
    writeNotNull('type', type);
    writeNotNull('hash', hash);
    writeNotNull('hashAlgorithmReadable', hashAlgorithmReadable);
    writeNotNull('hashAlgorithm', hashAlgorithm);
    return val;
  }

  String getFullSvgData() {
    return 'data:$type;base64,$base64Logo';
  }
}
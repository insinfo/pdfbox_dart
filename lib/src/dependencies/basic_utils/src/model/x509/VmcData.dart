



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
  factory VmcData.fromJson(Map<String, dynamic> json) =>
          throw  UnimplementedError();

  ///
  /// VmcData object to json
  ///
  Map<String, dynamic> toJson() =>     throw  UnimplementedError();

  String getFullSvgData() {
    return 'data:$type;base64,$base64Logo';
  }
}

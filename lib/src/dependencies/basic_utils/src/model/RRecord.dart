

class RRecord {
  /// The name of the record
  String name;

  /// The type of the record

  int rType;

  /// The time to live of the record

  int ttl;

  /// The data of the record
  String data;

  RRecord(
      {required this.name,
      required this.rType,
      required this.ttl,
      required this.data});

  /*
   * Json to RRecord object
   */
  factory RRecord.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();

  /*
   * RRecord object to json
   */
  Map<String, dynamic> toJson() => throw UnimplementedError();
}

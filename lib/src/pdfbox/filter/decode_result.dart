import '../cos/cos_dictionary.dart';

class DecodeResult {
  DecodeResult(this.parameters, {this.colorSpace, this.smask});

  factory DecodeResult.createDefault() => DecodeResult(COSDictionary());

  final COSDictionary parameters;
  final Object? colorSpace;
  final Object? smask;
}

import 'cos_base.dart';

class COSName extends COSBase implements Comparable<COSName> {
  COSName._(this.name);

  static final Map<String, COSName> _cache = <String, COSName>{};

  final String name;

  factory COSName(String name) =>
      _cache.putIfAbsent(name, () => COSName._(name));

  static COSName get(String name) => COSName(name);

  static final COSName type = COSName('Type');
  static final COSName pages = COSName('Pages');
  static final COSName page = COSName('Page');
  static final COSName mediaBox = COSName('MediaBox');
  static final COSName contents = COSName('Contents');
  static final COSName resources = COSName('Resources');
  static final COSName length = COSName('Length');
  static final COSName filter = COSName('Filter');
  static final COSName decodeParms = COSName('DecodeParms');
  static final COSName f = COSName('F');
  static final COSName dp = COSName('DP');
  static final COSName n = COSName('N');
  static final COSName predictor = COSName('Predictor');
  static final COSName colors = COSName('Colors');
  static final COSName bitsPerComponent = COSName('BitsPerComponent');
  static final COSName columns = COSName('Columns');

  @override
  int compareTo(COSName other) => name.compareTo(other.name);

  @override
  bool operator ==(Object other) => other is COSName && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '/$name';
}

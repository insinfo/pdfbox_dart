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
  static final COSName earlyChange = COSName('EarlyChange');
  static final COSName flateDecode = COSName('FlateDecode');
  static final COSName flateDecodeAbbreviation = COSName('Fl');
  static final COSName lzwDecode = COSName('LZWDecode');
  static final COSName lzwDecodeAbbreviation = COSName('LZW');
  static final COSName asciiHexDecode = COSName('ASCIIHexDecode');
  static final COSName asciiHexDecodeAbbreviation = COSName('AHx');
  static final COSName ascii85Decode = COSName('ASCII85Decode');
  static final COSName ascii85DecodeAbbreviation = COSName('A85');
  static final COSName runLengthDecode = COSName('RunLengthDecode');
  static final COSName runLengthDecodeAbbreviation = COSName('RL');
  static final COSName dctDecode = COSName('DCTDecode');
  static final COSName dctDecodeAbbreviation = COSName('DCT');

  @override
  int compareTo(COSName other) => name.compareTo(other.name);

  @override
  bool operator ==(Object other) => other is COSName && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '/$name';
}

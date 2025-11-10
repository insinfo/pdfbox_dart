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
  static final COSName root = COSName('Root');
  static final COSName parent = COSName('Parent');
  static final COSName kids = COSName('Kids');
  static final COSName count = COSName('Count');
  static final COSName subtype = COSName('Subtype');
  static final COSName mediaBox = COSName('MediaBox');
  static final COSName cropBox = COSName('CropBox');
  static final COSName contents = COSName('Contents');
  static final COSName resources = COSName('Resources');
  static final COSName font = COSName('Font');
  static final COSName baseFont = COSName('BaseFont');
  static final COSName encoding = COSName('Encoding');
  static final COSName fontDescriptor = COSName('FontDescriptor');
  static final COSName fontFile = COSName('FontFile');
  static final COSName fontFile2 = COSName('FontFile2');
  static final COSName fontFile3 = COSName('FontFile3');
  static final COSName fontName = COSName('FontName');
  static final COSName fontFamily = COSName('FontFamily');
  static final COSName fontStretch = COSName('FontStretch');
  static final COSName fontWeight = COSName('FontWeight');
  static final COSName fontBBox = COSName('FontBBox');
  static final COSName flags = COSName('Flags');
  static final COSName italicAngle = COSName('ItalicAngle');
  static final COSName ascent = COSName('Ascent');
  static final COSName descent = COSName('Descent');
  static final COSName leading = COSName('Leading');
  static final COSName capHeight = COSName('CapHeight');
  static final COSName xHeight = COSName('XHeight');
  static final COSName stemV = COSName('StemV');
  static final COSName stemH = COSName('StemH');
  static final COSName avgWidth = COSName('AvgWidth');
  static final COSName maxWidth = COSName('MaxWidth');
  static final COSName missingWidth = COSName('MissingWidth');
  static final COSName firstChar = COSName('FirstChar');
  static final COSName lastChar = COSName('LastChar');
  static final COSName widths = COSName('Widths');
  static final COSName type1 = COSName('Type1');
  static final COSName type0 = COSName('Type0');
  static final COSName trueType = COSName('TrueType');
  static final COSName cidFontType0 = COSName('CIDFontType0');
  static final COSName cidFontType2 = COSName('CIDFontType2');
  static final COSName cidSet = COSName('CIDSet');
  static final COSName descendantFonts = COSName('DescendantFonts');
  static final COSName cidSystemInfo = COSName('CIDSystemInfo');
  static final COSName registry = COSName('Registry');
  static final COSName ordering = COSName('Ordering');
  static final COSName supplement = COSName('Supplement');
  static final COSName toUnicode = COSName('ToUnicode');
  static final COSName cidToGidMap = COSName('CIDToGIDMap');
  static final COSName identity = COSName('Identity');
  static final COSName dw = COSName('DW');
  static final COSName dw2 = COSName('DW2');
  static final COSName w = COSName('W');
  static final COSName wMode = COSName('WMode');
  static final COSName w2 = COSName('W2');
  static final COSName procSet = COSName('ProcSet');
  static final COSName pattern = COSName('Pattern');
  static final COSName xObject = COSName('XObject');
  static final COSName colorSpace = COSName('ColorSpace');
  static final COSName length = COSName('Length');
  static final COSName length1 = COSName('Length1');
  static final COSName info = COSName('Info');
  static final COSName rotate = COSName('Rotate');
  static final COSName size = COSName('Size');
  static final COSName prev = COSName('Prev');
  static final COSName id = COSName('ID');
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
  static final COSName sig = COSName('Sig');
  static final COSName subFilter = COSName('SubFilter');
  static final COSName nameKey = COSName('Name');
  static final COSName location = COSName('Location');
  static final COSName reason = COSName('Reason');
  static final COSName contactInfo = COSName('ContactInfo');
  static final COSName m = COSName('M');
  static final COSName byteRange = COSName('ByteRange');
  static final COSName propBuild = COSName('Prop_Build');
  static final COSName app = COSName('App');
  static final COSName pubSec = COSName('PubSec');
  static final COSName os = COSName('OS');
  static final COSName preRelease = COSName('PreRelease');
  static final COSName nonEFontNoWarn = COSName('NonEFontNoWarn');
  static final COSName trustedMode = COSName('TrustedMode');
  static final COSName date = COSName('Date');
  static final COSName r = COSName('R');
  static final COSName v = COSName('V');
  static final COSName sv = COSName('SV');
  static final COSName svCert = COSName('SVCert');
  static final COSName ff = COSName('Ff');
  static final COSName digestMethod = COSName('DigestMethod');
  static final COSName digestSha1 = COSName('DigestSHA1');
  static final COSName digestSha256 = COSName('DigestSHA256');
  static final COSName digestSha384 = COSName('DigestSHA384');
  static final COSName digestSha512 = COSName('DigestSHA512');
  static final COSName digestRipemd160 = COSName('DigestRIPEMD160');
  static final COSName adobePpklite = COSName('Adobe.PPKLite');
  static final COSName entrustPpKef = COSName('Entrust.PPKEF');
  static final COSName ciciSignIt = COSName('CICI.SignIt');
  static final COSName verisignPpkvs = COSName('VeriSign.PPKVS');
  static final COSName adbeX509RsaSha1 = COSName('adbe.x509.rsa_sha1');
  static final COSName adbePkcs7Detached = COSName('adbe.pkcs7.detached');
  static final COSName adbePkcs7Sha1 = COSName('adbe.pkcs7.sha1');
  static final COSName etsiCadesDetached = COSName('ETSI.CAdES.detached');
  static final COSName reasons = COSName('Reasons');
  static final COSName legalAttestation = COSName('LegalAttestation');
  static final COSName addRevInfo = COSName('AddRevInfo');
  static final COSName url = COSName('URL');
  static final COSName ft = COSName('FT');
  static final COSName p = COSName('P');
  static final COSName cert = COSName('Cert');
  static final COSName timeStamp = COSName('TimeStamp');
  static final COSName mdp = COSName('MDP');
  static final COSName subject = COSName('Subject');
  static final COSName issuer = COSName('Issuer');
  static final COSName oid = COSName('OID');
  static final COSName subjectDn = COSName('SubjectDN');
  static final COSName keyUsage = COSName('KeyUsage');
  static final COSName urlType = COSName('URLType');

  @override
  int compareTo(COSName other) => name.compareTo(other.name);

  @override
  bool operator ==(Object other) => other is COSName && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '/$name';
}

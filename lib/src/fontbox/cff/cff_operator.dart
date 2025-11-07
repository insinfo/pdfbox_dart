/// Representa um operador CFF identificado pelos bytes b0/b1.
class CffOperator {
  CffOperator._();

  static final Map<int, String> _keyMap = <int, String>{
    ..._topDictEntries,
    ..._privateDictEntries,
  };

  static const Map<int, String> _topDictEntries = <int, String>{
    0x0000: 'version',
    0x0001: 'Notice',
    0x0C00: 'Copyright',
    0x0002: 'FullName',
    0x0003: 'FamilyName',
    0x0004: 'Weight',
    0x0C01: 'isFixedPitch',
    0x0C02: 'ItalicAngle',
    0x0C03: 'UnderlinePosition',
    0x0C04: 'UnderlineThickness',
    0x0C05: 'PaintType',
    0x0C06: 'CharstringType',
    0x0C07: 'FontMatrix',
    0x000D: 'UniqueID',
    0x0005: 'FontBBox',
    0x0C08: 'StrokeWidth',
    0x000E: 'XUID',
    0x000F: 'charset',
    0x0010: 'Encoding',
    0x0011: 'CharStrings',
    0x0012: 'Private',
    0x0C14: 'SyntheticBase',
    0x0C15: 'PostScript',
    0x0C16: 'BaseFontName',
    0x0C17: 'BaseFontBlend',
    0x0C1E: 'ROS',
    0x0C1F: 'CIDFontVersion',
    0x0C20: 'CIDFontRevision',
    0x0C21: 'CIDFontType',
    0x0C22: 'CIDCount',
    0x0C23: 'UIDBase',
    0x0C24: 'FDArray',
    0x0C25: 'FDSelect',
    0x0C26: 'FontName',
  };

  static const Map<int, String> _privateDictEntries = <int, String>{
    0x0006: 'BlueValues',
    0x0007: 'OtherBlues',
    0x0008: 'FamilyBlues',
    0x0009: 'FamilyOtherBlues',
    0x0C09: 'BlueScale',
    0x0C0A: 'BlueShift',
    0x0C0B: 'BlueFuzz',
    0x000A: 'StdHW',
    0x000B: 'StdVW',
    0x0C0C: 'StemSnapH',
    0x0C0D: 'StemSnapV',
    0x0C0E: 'ForceBold',
    0x0C0F: 'LanguageGroup',
    0x0C10: 'ExpansionFactor',
    0x0C11: 'initialRandomSeed',
    0x0013: 'Subrs',
    0x0014: 'defaultWidthX',
    0x0015: 'nominalWidthX',
  };

  /// Nome do operador para o par de bytes informado.
  static String? getOperator(int b0, [int b1 = 0]) => _keyMap[_key(b0, b1)];

  static int _key(int b0, int b1) => (b1 << 8) | (b0 & 0xFF);
}

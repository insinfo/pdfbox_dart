import 'data/unicode_scripts_data.dart';

/// Mapping between Unicode code points and OpenType script tags used by GSUB.
class OpenTypeScript {
  OpenTypeScript._();

  static const String inherited = 'Inherited';
  static const String unknown = 'Unknown';
  static const String tagDefault = 'DFLT';

  static const Map<String, List<String>> _scriptToTags = <String, List<String>>{
    'Adlam': <String>['adlm'],
    'Ahom': <String>['ahom'],
    'Anatolian_Hieroglyphs': <String>['hluw'],
    'Arabic': <String>['arab'],
    'Armenian': <String>['armn'],
    'Avestan': <String>['avst'],
    'Balinese': <String>['bali'],
    'Bamum': <String>['bamu'],
    'Bassa_Vah': <String>['bass'],
    'Batak': <String>['batk'],
    'Bengali': <String>['bng2', 'beng'],
    'Bhaiksuki': <String>['bhks'],
    'Bopomofo': <String>['bopo'],
    'Brahmi': <String>['brah'],
    'Braille': <String>['brai'],
    'Buginese': <String>['bugi'],
    'Buhid': <String>['buhd'],
    'Canadian_Aboriginal': <String>['cans'],
    'Carian': <String>['cari'],
    'Caucasian_Albanian': <String>['aghb'],
    'Chakma': <String>['cakm'],
    'Cham': <String>['cham'],
    'Cherokee': <String>['cher'],
    'Common': <String>[tagDefault],
    'Coptic': <String>['copt'],
    'Cuneiform': <String>['xsux'],
    'Cypriot': <String>['cprt'],
    'Cyrillic': <String>['cyrl'],
    'Deseret': <String>['dsrt'],
    'Devanagari': <String>['dev2', 'deva'],
    'Duployan': <String>['dupl'],
    'Egyptian_Hieroglyphs': <String>['egyp'],
    'Elbasan': <String>['elba'],
    'Ethiopic': <String>['ethi'],
    'Georgian': <String>['geor'],
    'Glagolitic': <String>['glag'],
    'Gothic': <String>['goth'],
    'Grantha': <String>['gran'],
    'Greek': <String>['grek'],
    'Gujarati': <String>['gjr2', 'gujr'],
    'Gurmukhi': <String>['gur2', 'guru'],
    'Han': <String>['hani'],
    'Hangul': <String>['hang'],
    'Hanunoo': <String>['hano'],
    'Hatran': <String>['hatr'],
    'Hebrew': <String>['hebr'],
    'Hiragana': <String>['kana'],
    'Imperial_Aramaic': <String>['armi'],
    inherited: <String>[inherited],
    'Inscriptional_Pahlavi': <String>['phli'],
    'Inscriptional_Parthian': <String>['prti'],
    'Javanese': <String>['java'],
    'Kaithi': <String>['kthi'],
    'Kannada': <String>['knd2', 'knda'],
    'Katakana': <String>['kana'],
    'Kayah_Li': <String>['kali'],
    'Kharoshthi': <String>['khar'],
    'Khmer': <String>['khmr'],
    'Khojki': <String>['khoj'],
    'Khudawadi': <String>['sind'],
    'Lao': <String>['lao '],
    'Latin': <String>['latn'],
    'Lepcha': <String>['lepc'],
    'Limbu': <String>['limb'],
    'Linear_A': <String>['lina'],
    'Linear_B': <String>['linb'],
    'Lisu': <String>['lisu'],
    'Lycian': <String>['lyci'],
    'Lydian': <String>['lydi'],
    'Mahajani': <String>['mahj'],
    'Malayalam': <String>['mlm2', 'mlym'],
    'Mandaic': <String>['mand'],
    'Manichaean': <String>['mani'],
    'Marchen': <String>['marc'],
    'Meetei_Mayek': <String>['mtei'],
    'Mende_Kikakui': <String>['mend'],
    'Meroitic_Cursive': <String>['merc'],
    'Meroitic_Hieroglyphs': <String>['mero'],
    'Miao': <String>['plrd'],
    'Modi': <String>['modi'],
    'Mongolian': <String>['mong'],
    'Mro': <String>['mroo'],
    'Multani': <String>['mult'],
    'Myanmar': <String>['mym2', 'mymr'],
    'Nabataean': <String>['nbat'],
    'Newa': <String>['newa'],
    'New_Tai_Lue': <String>['talu'],
    'Nko': <String>['nko '],
    'Ogham': <String>['ogam'],
    'Ol_Chiki': <String>['olck'],
    'Old_Italic': <String>['ital'],
    'Old_Hungarian': <String>['hung'],
    'Old_North_Arabian': <String>['narb'],
    'Old_Permic': <String>['perm'],
    'Old_Persian': <String>['xpeo'],
    'Old_South_Arabian': <String>['sarb'],
    'Old_Turkic': <String>['orkh'],
    'Oriya': <String>['ory2', 'orya'],
    'Osage': <String>['osge'],
    'Osmanya': <String>['osma'],
    'Pahawh_Hmong': <String>['hmng'],
    'Palmyrene': <String>['palm'],
    'Pau_Cin_Hau': <String>['pauc'],
    'Phags_Pa': <String>['phag'],
    'Phoenician': <String>['phnx'],
    'Psalter_Pahlavi': <String>['phlp'],
    'Rejang': <String>['rjng'],
    'Runic': <String>['runr'],
    'Samaritan': <String>['samr'],
    'Saurashtra': <String>['saur'],
    'Sharada': <String>['shrd'],
    'Shavian': <String>['shaw'],
    'Siddham': <String>['sidd'],
    'SignWriting': <String>['sgnw'],
    'Sinhala': <String>['sinh'],
    'Sora_Sompeng': <String>['sora'],
    'Sundanese': <String>['sund'],
    'Syloti_Nagri': <String>['sylo'],
    'Syriac': <String>['syrc'],
    'Tagalog': <String>['tglg'],
    'Tagbanwa': <String>['tagb'],
    'Tai_Le': <String>['tale'],
    'Tai_Tham': <String>['lana'],
    'Tai_Viet': <String>['tavt'],
    'Takri': <String>['takr'],
    'Tamil': <String>['tml2', 'taml'],
    'Tangut': <String>['tang'],
    'Telugu': <String>['tel2', 'telu'],
    'Thaana': <String>['thaa'],
    'Thai': <String>['thai'],
    'Tibetan': <String>['tibt'],
    'Tifinagh': <String>['tfng'],
    'Tirhuta': <String>['tirh'],
    'Ugaritic': <String>['ugar'],
    unknown: <String>[tagDefault],
    'Vai': <String>['vai '],
    'Warang_Citi': <String>['wara'],
    'Yi': <String>['yi  '],
  };

  /// Returns the OpenType script tags associated with [codePoint].
  static List<String> getScriptTags(int codePoint) {
    _ensureValid(codePoint);
    final script = _unicodeScript(codePoint);
    return _scriptToTags[script] ?? const <String>[tagDefault];
  }

  static void _ensureValid(int codePoint) {
    if (codePoint < 0 || codePoint > 0x10FFFF) {
      throw ArgumentError.value(
          codePoint, 'codePoint', 'Invalid Unicode scalar value');
    }
  }

  static String _unicodeScript(int codePoint) {
    var low = 0;
    var high = unicodeRangeStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final start = unicodeRangeStarts[mid];
      if (codePoint < start) {
        high = mid - 1;
        continue;
      }
      final end = unicodeRangeEnds[mid];
      if (codePoint > end) {
        low = mid + 1;
        continue;
      }
      return unicodeRangeScripts[mid];
    }
    return unknown;
  }
}

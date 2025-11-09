/// Languages supported for GSUB processing.
enum Language {
  bengali(<String>['bng2', 'beng']),
  devanagari(<String>['dev2', 'deva']),
  gujarati(<String>['gjr2', 'gujr']),
  latin(<String>['latn']),
  arabic(<String>['arab']),
  armenian(<String>['armn']),
  cyrillic(<String>['cyrl']),
  ethiopic(<String>['ethi']),
  georgian(<String>['geor']),
  greek(<String>['grek']),
  hebrew(<String>['hebr']),
  khmer(<String>['khmr']),
  lao(<String>['lao ']),
  gurmukhi(<String>['guru']),
  kannada(<String>['knda']),
  malayalam(<String>['mlym']),
  oriya(<String>['orya']),
  hangul(<String>['hang']),
  han(<String>['hani']),
  kana(<String>['kana']),
  bopomofo(<String>['bopo']),
  myanmar(<String>['mym2', 'mymr']),
  sinhala(<String>['sinh']),
  tamil(<String>['tml2', 'taml']),
  telugu(<String>['tel2', 'telu']),
  thai(<String>['thai']),
  tibetan(<String>['tibt']),
  unspecified(<String>[]);

  const Language(this.scriptNames);

  final List<String> scriptNames;
}

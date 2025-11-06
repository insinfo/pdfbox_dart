/// Languages supported for GSUB processing.
enum Language {
  bengali(<String>['bng2', 'beng']),
  devanagari(<String>['dev2', 'deva']),
  gujarati(<String>['gjr2', 'gujr']),
  latin(<String>['latn']),
  unspecified(<String>[]);

  const Language(this.scriptNames);

  final List<String> scriptNames;
}

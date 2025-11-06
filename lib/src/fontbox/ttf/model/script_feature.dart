/// Models a substitution feature record extracted from GSUB tables.
abstract class ScriptFeature {
  String get name;

  Set<List<int>> getAllGlyphIdsForSubstitution();

  bool canReplaceGlyphs(List<int> glyphIds);

  List<int> getReplacementForGlyphs(List<int> glyphIds);
}

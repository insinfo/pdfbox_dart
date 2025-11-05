/// Contrato para consultas bidirecionais entre códigos Unicode e glyph IDs.
abstract class CMapLookup {
  /// Retorna o glyph ID associado ao [codePoint].
  ///
  /// Implementações devem retornar `0` quando não houver mapeamento.
  int getGlyphId(int codePoint);

  /// Retorna todos os codepoints associados ao [glyphId], ou `null` se inexistente.
  List<int>? getCharCodes(int glyphId);
}

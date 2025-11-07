/// Contrato para consultas bidirecionais entre códigos Unicode e glyph IDs.
abstract class CMapLookup {
  /// Retorna o glyph ID associado ao [codePoint], considerando um seletor de
  /// variação opcional.
  ///
  /// Implementações devem retornar `0` quando não houver mapeamento válido.
  int getGlyphId(int codePoint, [int? variationSelector]);

  /// Retorna todos os codepoints associados ao [glyphId], ou `null` se inexistente.
  List<int>? getCharCodes(int glyphId);
}

import 'dart:collection';

import 'cmap_lookup.dart';

/// Implementação básica de `CMapLookup` baseada na estrutura da `CmapSubtable`
/// do PDFBox. Esta versão foca em disponibilizar o contrato de consulta
/// bidirecional entre codepoints e glyph IDs, deixando para etapas futuras a
/// leitura binária dos formatos específicos do cmap TrueType/OpenType.
class CmapSubtable implements CMapLookup {
  final Map<int, int> _characterCodeToGlyphId = <int, int>{};
  final Map<int, List<int>> _glyphIdToCharacterCodes = <int, List<int>>{};

  /// Identificadores de plataforma/encoding definidos pela subtable.
  int platformId = 0;
  int platformEncodingId = 0;

  /// Registra um mapeamento entre um [codePoint] e o [glyphId] correspondente.
  /// Se o mapeamento já existir, ele é sobrescrito para manter o comportamento
  /// do Java, que trata a última ocorrência como a vigente.
  void addMapping(int codePoint, int glyphId) {
    final previousGlyph = _characterCodeToGlyphId[codePoint];
    if (previousGlyph != null && previousGlyph != glyphId) {
      final previousList = _glyphIdToCharacterCodes[previousGlyph];
      previousList?.remove(codePoint);
      if (previousList != null && previousList.isEmpty) {
        _glyphIdToCharacterCodes.remove(previousGlyph);
      }
    }
    _characterCodeToGlyphId[codePoint] = glyphId;
    final codes = _glyphIdToCharacterCodes.putIfAbsent(glyphId, () => <int>[]);
    if (!codes.contains(codePoint)) {
      codes.add(codePoint);
      codes.sort();
    }
  }

  /// Remove um mapeamento entre [codePoint] e o glyph correspondente.
  void removeMapping(int codePoint) {
    final glyphId = _characterCodeToGlyphId.remove(codePoint);
    if (glyphId == null) {
      return;
    }
    final codes = _glyphIdToCharacterCodes[glyphId];
    codes?.remove(codePoint);
    if (codes != null && codes.isEmpty) {
      _glyphIdToCharacterCodes.remove(glyphId);
    }
  }

  /// Retorna todos os mapeamentos atuais como um mapa imutável.
  Map<int, int> get characterCodeToGlyphId => UnmodifiableMapView(_characterCodeToGlyphId);

  /// Retorna os codepoints associados a [glyphId], preservando ordenação.
  @override
  List<int>? getCharCodes(int glyphId) {
    final codes = _glyphIdToCharacterCodes[glyphId];
    return codes == null ? null : List<int>.unmodifiable(codes);
  }

  /// Resolve o glyph ID para o [codePoint] fornecido.
  @override
  int getGlyphId(int codePoint) => _characterCodeToGlyphId[codePoint] ?? 0;

  /// Indica se há algum mapeamento registrado.
  bool get isEmpty => _characterCodeToGlyphId.isEmpty;

  int get mappingCount => _characterCodeToGlyphId.length;

  /// Copia os mapeamentos de outra subtable.
  void copyFrom(CmapSubtable other) {
    other._characterCodeToGlyphId.forEach(addMapping);
  }
}

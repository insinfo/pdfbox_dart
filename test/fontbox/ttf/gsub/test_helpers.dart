import 'package:pdfbox_dart/src/fontbox/ttf/cmap_lookup.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/map_backed_gsub_data.dart';

class FakeCMapLookup implements CMapLookup {
  FakeCMapLookup(Map<int, int> glyphMapping)
      : _glyphMapping = Map<int, int>.from(glyphMapping);

  final Map<int, int> _glyphMapping;

  @override
  int getGlyphId(int codePoint) => _glyphMapping[codePoint] ?? 0;

  @override
  List<int>? getCharCodes(int glyphId) => null;
}

MapBackedGsubData buildGsubData(
  Language language,
  String scriptName, {
  Map<String, Map<List<int>, List<int>>> features =
      const <String, Map<List<int>, List<int>>>{},
}) {
  final copied = <String, Map<List<int>, List<int>>>{};
  features.forEach((key, value) {
    copied[key] = value.map((glyphs, replacement) => MapEntry(
          List<int>.from(glyphs),
          List<int>.from(replacement),
        ));
  });
  return MapBackedGsubData(language, scriptName, copied);
}

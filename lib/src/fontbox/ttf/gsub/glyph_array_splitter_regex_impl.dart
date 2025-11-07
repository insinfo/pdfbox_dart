import 'dart:collection';
import 'compound_character_tokenizer.dart';
import 'glyph_array_splitter.dart';

/// Regex-based splitter that tokenizes glyph sequences for GSUB replacements.
class GlyphArraySplitterRegexImpl implements GlyphArraySplitter {
  GlyphArraySplitterRegexImpl(Set<List<int>> matchers)
      : _tokenizer = CompoundCharacterTokenizer(_buildMatchers(matchers));

  static const String _glyphIdSeparator = '_';

  final CompoundCharacterTokenizer _tokenizer;

  static Set<String> _buildMatchers(Set<List<int>> matchers) {
    final tree = SplayTreeSet<String>((a, b) {
      if (a.length == b.length) {
        return b.compareTo(a);
      }
      return b.length.compareTo(a.length);
    });
    for (final glyphs in matchers) {
      tree.add(_convertGlyphIdsToString(glyphs));
    }
    return tree;
  }

  @override
  List<List<int>> split(List<int> glyphIds) {
    final text = _convertGlyphIdsToString(glyphIds);
    final tokens = _tokenizer.tokenize(text);
    return tokens.map(_convertGlyphIdsToList).toList(growable: false);
  }

  static String _convertGlyphIdsToString(List<int> glyphIds) {
    final buffer = StringBuffer(_glyphIdSeparator);
    for (final glyphId in glyphIds) {
      buffer.write(glyphId);
      buffer.write(_glyphIdSeparator);
    }
    return buffer.toString();
  }

  static List<int> _convertGlyphIdsToList(String glyphIdsAsString) {
    final result = <int>[];
    final parts = glyphIdsAsString.split(_glyphIdSeparator);
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      result.add(int.parse(trimmed));
    }
    return List<int>.unmodifiable(result);
  }
}

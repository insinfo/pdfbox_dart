import 'dart:collection';

/// Splits text representing compound glyph sequences into tokens.
class CompoundCharacterTokenizer {
  CompoundCharacterTokenizer(Set<String> compoundWords)
      : _regexExpression = _buildRegex(compoundWords);

  static const String _glyphIdSeparator = '_';

  final RegExp _regexExpression;

  static RegExp _buildRegex(Set<String> compoundWords) {
    _validateCompoundWords(compoundWords);
    final pattern = '(${compoundWords.join(')|(')})';
    return RegExp(pattern);
  }

  static void _validateCompoundWords(Set<String> compoundWords) {
    if (compoundWords.isEmpty) {
      throw ArgumentError('Compound words cannot be empty');
    }
    for (final word in compoundWords) {
      if (!word.startsWith(_glyphIdSeparator) ||
          !word.endsWith(_glyphIdSeparator)) {
        throw ArgumentError(
          'Compound words should start and end with $_glyphIdSeparator: $word',
        );
      }
    }
  }

  /// Tokenize a string like "_66_71_71_" into GSUB chunks.
  List<String> tokenize(String text) {
    final tokens = <String>[];
    var lastIndex = 0;
    final matches = _regexExpression.allMatches(text);
    for (final match in matches) {
      final start = match.start;
      final prevToken = text.substring(lastIndex, start);
      if (prevToken.isNotEmpty) {
        tokens.add(prevToken);
      }
      final current = match.group(0)!;
      tokens.add(current);
      lastIndex = match.end;
      if (lastIndex < text.length &&
          text.codeUnitAt(lastIndex) != _glyphIdSeparator.codeUnitAt(0)) {
        lastIndex--;
      }
    }
    final tail = text.substring(lastIndex);
    if (tail.isNotEmpty) {
      tokens.add(tail);
    }
    return UnmodifiableListView<String>(tokens);
  }
}

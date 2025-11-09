import 'dart:collection';

/// Base class for PostScript-style encoding vectors.
abstract class Encoding {
  final Map<int, String> _codeToName = <int, String>{};
  final Map<String, int> _nameToCode = <String, int>{};

  /// Registers a mapping between a character code and glyph name.
  void addCharacterEncoding(int code, String name) {
    _codeToName[code] = name;
    _nameToCode[name] = code;
  }

  /// Returns the character code for the provided glyph [name], or null when missing.
  int? getCode(String name) => _nameToCode[name];

  /// Returns the glyph name associated with [code], defaulting to ".notdef".
  String getName(int code) => _codeToName[code] ?? '.notdef';

  /// Returns `true` when the encoding assigns a code to [name].
  bool contains(String name) => _nameToCode.containsKey(name);

  /// Exposes an immutable view of the code-to-name assignments.
  Map<int, String> get codeToNameMap => UnmodifiableMapView(_codeToName);
}

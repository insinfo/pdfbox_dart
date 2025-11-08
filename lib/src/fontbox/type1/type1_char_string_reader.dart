import '../cff/type1_char_string.dart';

/// Contract for components capable of providing Type 1 CharStrings.
abstract class Type1CharStringReader {
  /// Returns the Type 1 CharString associated with [name].
  Type1CharString getType1CharString(String name);
}

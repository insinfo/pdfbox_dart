import 'dart:typed_data';

import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import 'predefined_cmaps.dart';

/// Provides access to the embedded predefined CMap resources.
class PredefinedCMapRepository {
  PredefinedCMapRepository._();

  /// Opens a predefined CMap as a [RandomAccessRead].
  ///
  /// Throws [ArgumentError] if the requested CMap does not exist.
  static RandomAccessRead open(String name) {
    final normalized = name.trim();
    final bytes = PredefinedCMapData.getBytes(normalized);
    if (bytes == null) {
      throw ArgumentError('Unknown predefined CMap "$name"');
    }
    return RandomAccessReadBuffer.fromBytes(Uint8List.fromList(bytes));
  }

  /// Returns true if a predefined CMap with the given [name] exists.
  static bool contains(String name) => PredefinedCMapData.getBytes(name.trim()) != null;

  /// Returns the list of embedded predefined CMap names.
  static List<String> list() => List<String>.unmodifiable(PredefinedCMapData.names);
}

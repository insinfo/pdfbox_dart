import 'dart:typed_data' as typed;

import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// Compact Font Format (CFF) table containing PostScript outlines.
///
/// The full CFF parser is not yet available in the Dart port. For now we cache
/// the raw table bytes so downstream consumers can forward them to an external
/// decoder or defer parsing until additional modules are ported.
class CffTable extends TtfTable {
  static const String tableTag = 'CFF ';

  typed.Uint8List? _rawData;

  /// Returns an immutable view of the raw CFF data, if this table has been
  /// initialised.
  typed.Uint8List get rawData {
    final data = _rawData;
    if (data == null) {
      throw StateError('CFF table has not been read');
    }
    return typed.Uint8List.fromList(data);
  }

  /// Whether the raw CFF bytes are available.
  bool get hasData => _rawData != null;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    _rawData = data.readBytes(length);
    setInitialized(true);
  }
}

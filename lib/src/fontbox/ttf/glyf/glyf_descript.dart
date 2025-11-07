import '../../io/ttf_data_stream.dart';
import 'glyph_description.dart';

/// Base class shared by simple and composite glyph descriptions.
abstract class GlyfDescript implements GlyphDescription {
  /// Flag indicating the point lies directly on the curve.
  static const int ON_CURVE = 0x01;

  /// Flag indicating the X coordinate is encoded as an 8-bit delta.
  static const int X_SHORT_VECTOR = 0x02;

  /// Flag indicating the Y coordinate is encoded as an 8-bit delta.
  static const int Y_SHORT_VECTOR = 0x04;

  /// Flag indicating the current flag byte should be repeated.
  static const int REPEAT = 0x08;

  /// Flag whose interpretation depends on [xShortVector].
  static const int X_DUAL = 0x10;

  /// Flag whose interpretation depends on [yShortVector].
  static const int Y_DUAL = 0x20;

  GlyfDescript(this._contourCount);

  final int _contourCount;
  List<int>? _instructions;

  @override
  int get contourCount => _contourCount;

  List<int>? get instructions => _instructions;

  void readInstructions(TtfDataStream data, int count) {
    _instructions = data.readUnsignedByteArray(count);
  }

  @override
  void resolve() {}
}

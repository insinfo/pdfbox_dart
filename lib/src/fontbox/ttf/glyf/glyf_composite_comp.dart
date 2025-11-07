import '../../io/ttf_data_stream.dart';

/// Component record describing a glyph referenced by a composite glyph.
class GlyfCompositeComp {
  GlyfCompositeComp(TtfDataStream data)
      : flags = data.readSignedShort(),
        glyphIndex = data.readUnsignedShort() {
    int arg1;
    int arg2;
    if ((flags & ARG_1_AND_2_ARE_WORDS) != 0) {
      arg1 = data.readSignedShort();
      arg2 = data.readSignedShort();
    } else {
      arg1 = data.readSignedByte();
      arg2 = data.readSignedByte();
    }
    argument1 = arg1;
    argument2 = arg2;

    if ((flags & ARGS_ARE_XY_VALUES) != 0) {
      xTranslate = argument1;
      yTranslate = argument2;
    } else {
      point1 = argument1;
      point2 = argument2;
    }

    if ((flags & WE_HAVE_A_SCALE) != 0) {
      final value = data.readSignedShort();
      xScale = yScale = value / 0x4000;
    } else if ((flags & WE_HAVE_AN_X_AND_Y_SCALE) != 0) {
      xScale = data.readSignedShort() / 0x4000;
      yScale = data.readSignedShort() / 0x4000;
    } else if ((flags & WE_HAVE_A_TWO_BY_TWO) != 0) {
      xScale = data.readSignedShort() / 0x4000;
      scale01 = data.readSignedShort() / 0x4000;
      scale10 = data.readSignedShort() / 0x4000;
      yScale = data.readSignedShort() / 0x4000;
    }
  }

  static const int ARG_1_AND_2_ARE_WORDS = 0x0001;
  static const int ARGS_ARE_XY_VALUES = 0x0002;
  static const int ROUND_XY_TO_GRID = 0x0004;
  static const int WE_HAVE_A_SCALE = 0x0008;
  static const int MORE_COMPONENTS = 0x0020;
  static const int WE_HAVE_AN_X_AND_Y_SCALE = 0x0040;
  static const int WE_HAVE_A_TWO_BY_TWO = 0x0080;
  static const int WE_HAVE_INSTRUCTIONS = 0x0100;
  static const int USE_MY_METRICS = 0x0200;

  final int flags;
  final int glyphIndex;
  late final int argument1;
  late final int argument2;

  double xScale = 1.0;
  double yScale = 1.0;
  double scale01 = 0.0;
  double scale10 = 0.0;
  int xTranslate = 0;
  int yTranslate = 0;
  int point1 = 0;
  int point2 = 0;

  int _firstIndex = 0;
  int _firstContour = 0;

  void setFirstIndex(int index) => _firstIndex = index;
  int get firstIndex => _firstIndex;

  void setFirstContour(int contour) => _firstContour = contour;
  int get firstContour => _firstContour;

  int scaleX(int x, int y) => (x * xScale + y * scale10).round();

  int scaleY(int x, int y) => (x * scale01 + y * yScale).round();
}

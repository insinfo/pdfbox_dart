import '../io/ttf_data_stream.dart';
import '../util/bounding_box.dart';
import 'glyf/glyph_description.dart';
import 'glyf/glyf_composite_descript.dart';
import 'glyf/glyf_simple_descript.dart';
import 'glyph_renderer.dart';
import 'glyph_table.dart';

/// Glyph record stored within the 'glyf' table.
class GlyphData {
  int xMin = 0;
  int yMin = 0;
  int xMax = 0;
  int yMax = 0;
  BoundingBox boundingBox = BoundingBox();
  int numberOfContours = 0;
  GlyphDescription? _glyphDescription;

  GlyphDescription? get description => _glyphDescription;

  void initData(
      GlyphTable table, TtfDataStream data, int leftSideBearing, int level) {
    numberOfContours = data.readSignedShort();
    xMin = data.readSignedShort();
    yMin = data.readSignedShort();
    xMax = data.readSignedShort();
    yMax = data.readSignedShort();
    boundingBox = BoundingBox.fromValues(
        xMin.toDouble(), yMin.toDouble(), xMax.toDouble(), yMax.toDouble());

    if (numberOfContours >= 0) {
      final initialX = leftSideBearing - xMin;
      _glyphDescription = GlyfSimpleDescript(numberOfContours, data, initialX);
    } else {
      _glyphDescription = GlyfCompositeDescript(data, table, level + 1);
    }
  }

  void initEmptyData() {
    _glyphDescription = GlyfSimpleDescript.empty();
    boundingBox = BoundingBox();
  }

  int getXMaximum() => xMax;
  int getXMinimum() => xMin;
  int getYMaximum() => yMax;
  int getYMinimum() => yMin;

  /// Generates a `GlyphPath` representing this glyph's outline.
  GlyphPath getPath() {
    final description = _glyphDescription;
    if (description == null) {
      throw StateError('Glyph description has not been initialised');
    }
    return GlyphRenderer(description).getPath();
  }
}

import '../../../io/ttf_data_stream.dart';
import '../../ttf_table.dart';
import 'font_variation_axis.dart';

/// OpenType 'fvar' table exposing variation axes and named instances.
class FvarTable extends TtfTable {
  static const String tableTag = 'fvar';

  List<FontVariationAxis> _axes = const <FontVariationAxis>[];

  List<FontVariationAxis> get axes => _axes;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final tableStart = data.currentPosition;
    data.readUnsignedInt(); // version (Fixed 16.16)
    final offsetToData = data.readUnsignedShort();
    final countSizePairs = data.readUnsignedShort();
    if (countSizePairs < 2) {
      // Spec mandates at least axis and instance pairs; continue with defaults.
      data.seek(tableStart + offsetToData);
    }
    final axisCount = data.readUnsignedShort();
    final axisSize = data.readUnsignedShort();
    final instanceCount = data.readUnsignedShort();
    final instanceSize = data.readUnsignedShort();

    final axes = <FontVariationAxis>[];
    final axisArrayOffset = tableStart + offsetToData;
    for (var i = 0; i < axisCount; i++) {
      final recordOffset = axisArrayOffset + i * axisSize;
      data.seek(recordOffset);
      final tag = data.readString(4);
      final minValue = data.read32Fixed();
      final defaultValue = data.read32Fixed();
      final maxValue = data.read32Fixed();
      final flags = data.readUnsignedShort();
      final axisNameId = data.readUnsignedShort();
      axes.add(FontVariationAxis(
        tag: tag,
        minValue: minValue,
        defaultValue: defaultValue,
        maxValue: maxValue,
        flags: flags,
        axisNameId: axisNameId,
      ));
    }

    // Skip named instances; not yet required for variation resolution.
    final instancesOffset = axisArrayOffset + axisCount * axisSize;
    final skipLength = instanceCount * instanceSize;
    if (skipLength > 0) {
      data.seek(instancesOffset + skipLength);
    }

    _axes = List<FontVariationAxis>.unmodifiable(axes);
    if (ttf is VariationAxisConsumer) {
      ttf.updateVariationAxes(_axes);
    }
    setInitialized(true);
  }
}

/// Consumer interface implemented by [TrueTypeFont] to receive axis updates.
abstract class VariationAxisConsumer {
  void updateVariationAxes(List<FontVariationAxis> axes);
}

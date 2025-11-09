import 'package:pdfbox_dart/src/io/export.dart';

import '../../../io/ttf_data_stream.dart';

class FeatureVariationRecord {
  const FeatureVariationRecord(
      this.conditions, this.featureTableSubstitutionOffset);

  final List<FeatureVariationCondition> conditions;
  final int featureTableSubstitutionOffset;

  bool get hasConditions => conditions.isNotEmpty;
}

class FeatureVariationCondition {
  const FeatureVariationCondition(this.axisIndex, this.minValue, this.maxValue);

  final int axisIndex;
  final double minValue;
  final double maxValue;
}

List<FeatureVariationRecord> readFeatureVariations(
  TtfDataStream data,
  int offset,
) {
  final saved = data.currentPosition;
  data.seek(offset);
  final count = data.readUnsignedInt();
  final records = <FeatureVariationRecord>[];
  for (var i = 0; i < count; i++) {
    final conditionSetOffset = data.readUnsignedInt();
    final substitutionOffset = data.readUnsignedInt();
    final conditions = conditionSetOffset == 0
        ? const <FeatureVariationCondition>[]
        : _readConditionSet(data, offset + conditionSetOffset);
    records.add(FeatureVariationRecord(
      conditions,
      substitutionOffset == 0 ? 0 : offset + substitutionOffset,
    ));
  }
  data.seek(saved);
  return List<FeatureVariationRecord>.unmodifiable(records);
}

List<FeatureVariationCondition> _readConditionSet(
  TtfDataStream data,
  int offset,
) {
  final saved = data.currentPosition;
  data.seek(offset);
  final conditionCount = data.readUnsignedShort();
  final conditionOffsets = data.readUnsignedShortArray(conditionCount);
  final conditions = <FeatureVariationCondition>[];
  for (var i = 0; i < conditionCount; i++) {
    final conditionOffset = conditionOffsets[i];
    if (conditionOffset == 0) {
      continue;
    }
    final condition = _readConditionTable(data, offset + conditionOffset);
    if (condition != null) {
      conditions.add(condition);
    }
  }
  data.seek(saved);
  return List<FeatureVariationCondition>.unmodifiable(conditions);
}

FeatureVariationCondition? _readConditionTable(
  TtfDataStream data,
  int offset,
) {
  final saved = data.currentPosition;
  data.seek(offset);
  try {
    final format = data.readUnsignedShort();
    if (format != 1) {
      throw IOException(
          'Unsupported FeatureVariation condition format $format');
    }
    final axisIndex = data.readUnsignedShort();
    final filterRangeMinValue = data.readSignedShort();
    final filterRangeMaxValue = data.readSignedShort();
    return FeatureVariationCondition(
      axisIndex,
      _fromF2Dot14(filterRangeMinValue),
      _fromF2Dot14(filterRangeMaxValue),
    );
  } on IOException {
    return null;
  } finally {
    data.seek(saved);
  }
}

double _fromF2Dot14(int value) => value / 16384.0;

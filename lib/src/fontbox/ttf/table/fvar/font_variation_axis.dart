class FontVariationAxis {
  const FontVariationAxis({
    required this.tag,
    required this.minValue,
    required this.defaultValue,
    required this.maxValue,
    required this.flags,
    required this.axisNameId,
  });

  final String tag;
  final double minValue;
  final double defaultValue;
  final double maxValue;
  final int flags;
  final int axisNameId;
}

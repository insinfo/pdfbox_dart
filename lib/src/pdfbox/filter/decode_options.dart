class DecodeOptions {
  const DecodeOptions({
    this.subsamplingX = 1,
    this.subsamplingY = 1,
    this.preserveRawDct = false,
  });

  static const DecodeOptions defaultOptions = DecodeOptions();

  final int subsamplingX;
  final int subsamplingY;
  final bool preserveRawDct;

  DecodeOptions copyWith({
    int? subsamplingX,
    int? subsamplingY,
    bool? preserveRawDct,
  }) {
    return DecodeOptions(
      subsamplingX: subsamplingX ?? this.subsamplingX,
      subsamplingY: subsamplingY ?? this.subsamplingY,
      preserveRawDct: preserveRawDct ?? this.preserveRawDct,
    );
  }

  bool get honored => true;
}

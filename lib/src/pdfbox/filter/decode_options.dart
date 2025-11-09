class DecodeOptions {
  const DecodeOptions({this.subsamplingX = 1, this.subsamplingY = 1});

  static const DecodeOptions defaultOptions = DecodeOptions();

  final int subsamplingX;
  final int subsamplingY;

  bool get honored => true;
}

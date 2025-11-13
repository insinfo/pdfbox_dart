class CompressParameters {
  const CompressParameters([this.objectStreamSize = defaultObjectStreamSize])
      : assert(objectStreamSize >= 0);

  static const int defaultObjectStreamSize = 200;

  static const CompressParameters defaultCompression =
      CompressParameters(defaultObjectStreamSize);

  static const CompressParameters noCompression = CompressParameters(0);

  final int objectStreamSize;

  bool get isCompress => objectStreamSize > 0;
}

class COSObjectKey {
  const COSObjectKey(this.objectNumber, this.generationNumber, [this.streamIndex = -1])
      : assert(objectNumber >= 0),
        assert(generationNumber >= 0),
        assert(streamIndex >= -1);

  final int objectNumber;
  final int generationNumber;
  final int streamIndex;

  bool get hasStreamIndex => streamIndex >= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! COSObjectKey) {
      return false;
    }
    return other.objectNumber == objectNumber &&
        other.generationNumber == generationNumber;
  }

  @override
  int get hashCode => Object.hash(objectNumber, generationNumber);

  @override
  String toString() => '$objectNumber $generationNumber R';
}

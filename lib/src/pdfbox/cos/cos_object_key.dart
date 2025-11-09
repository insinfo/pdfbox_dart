class COSObjectKey {
  const COSObjectKey(this.objectNumber, this.generationNumber);

  final int objectNumber;
  final int generationNumber;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is COSObjectKey &&
        other.objectNumber == objectNumber &&
        other.generationNumber == generationNumber;
  }

  @override
  int get hashCode => Object.hash(objectNumber, generationNumber);

  @override
  String toString() => '$objectNumber $generationNumber R';
}

enum XReferenceType {
  free(0),
  normal(1),
  objectStreamEntry(2);

  const XReferenceType(this.numericValue);

  final int numericValue;
}

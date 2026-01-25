/// Cardinality of XMP properties.
/// Ported from org.apache.xmpbox.type.Cardinality
enum Cardinality {
  /// Simple value (not an array).
  simple(false),
  
  /// Unordered array (bag).
  bag(true),
  
  /// Ordered array (sequence).
  seq(true),
  
  /// Alternative array.
  alt(true);

  final bool _isArray;

  const Cardinality(this._isArray);

  /// Returns true if this cardinality represents an array type.
  bool get isArray => _isArray;
}


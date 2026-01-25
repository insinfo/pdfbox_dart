/// XMP type enumeration.
/// Ported from org.apache.xmpbox.type.Types
enum Types {
  // Structure types
  structured(false, null),
  definedType(false, null),

  // Basic types
  text(true, null),
  date(true, null),
  boolean_(true, null),
  integer(true, null),
  real(true, null),
  gpsCoordinate(true, null), // Uses text as basic

  // Derived text types
  properName(true, null),
  locale(true, null),
  agentName(true, null),
  guid(true, null),
  xPath(true, null),
  part(true, null),
  url(true, null),
  uri(true, null),
  choice(true, null),
  mimeType(true, null),
  langAlt(true, null),
  renditionClass(true, null),
  rational(true, null),

  // Structured types
  layer(false, Types.structured),
  thumbnail(false, Types.structured),
  resourceEvent(false, Types.structured),
  resourceRef(false, Types.structured),
  version(false, Types.structured),
  pdfaSchema(false, Types.structured),
  pdfaField(false, Types.structured),
  pdfaProperty(false, Types.structured),
  pdfaType(false, Types.structured),
  job(false, Types.structured),
  oecf(false, Types.structured),
  cfaPattern(false, Types.structured),
  deviceSettings(false, Types.structured),
  flash(false, Types.structured),
  dimensions(false, Types.structured);

  final bool _isSimple;
  final Types? _basic;

  const Types(this._isSimple, this._basic);

  /// Returns true if this is a simple type.
  bool get isSimple => _isSimple;

  /// Returns true if this is a basic type (no parent type).
  bool get isBasic => _basic == null;

  /// Returns true if this is a structured type.
  bool get isStructured => _basic == Types.structured;

  /// Returns true if this is a defined type.
  bool get isDefined => this == Types.definedType;

  /// Get the basic type this type derives from.
  Types? get basic => _basic;
}


/// Text rendering mode that determines how glyphs are painted and clipped.
enum RenderingMode {
  fill(0),
  stroke(1),
  fillStroke(2),
  neither(3),
  fillClip(4),
  strokeClip(5),
  fillStrokeClip(6),
  neitherClip(7);

  const RenderingMode(this.value);

  /// Integer representation used in PDF content streams.
  final int value;

  /// Resolves a mode from its integer identifier.
  static RenderingMode fromInt(int value) => RenderingMode.values[value];

  /// Indicates whether this mode fills glyph outlines.
  bool get isFill =>
      this == RenderingMode.fill ||
      this == RenderingMode.fillStroke ||
      this == RenderingMode.fillClip ||
      this == RenderingMode.fillStrokeClip;

  /// Indicates whether this mode strokes glyph outlines.
  bool get isStroke =>
      this == RenderingMode.stroke ||
      this == RenderingMode.fillStroke ||
      this == RenderingMode.strokeClip ||
      this == RenderingMode.fillStrokeClip;

  /// Indicates whether this mode adds glyph outlines to the clipping path.
  bool get isClip =>
      this == RenderingMode.fillClip ||
      this == RenderingMode.strokeClip ||
      this == RenderingMode.fillStrokeClip ||
      this == RenderingMode.neitherClip;
}

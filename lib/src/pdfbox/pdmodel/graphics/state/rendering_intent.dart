/// Rendering intents specify how colors should be adapted between color spaces.
enum RenderingIntent {
  absoluteColorimetric('AbsoluteColorimetric'),
  relativeColorimetric('RelativeColorimetric'),
  saturation('Saturation'),
  perceptual('Perceptual');

  const RenderingIntent(this.value);

  /// Literal value recorded in PDFs.
  final String value;

  /// Resolves an intent from its PDF literal.
  static RenderingIntent fromString(String value) {
    for (final intent in RenderingIntent.values) {
      if (intent.value == value) {
        return intent;
      }
    }
    return RenderingIntent.relativeColorimetric;
  }

  /// Returns the PDF literal associated with this intent.
  String get stringValue => value;
}

/// Defines how the document viewer should present the document when opened.
enum PageMode {
  useNone('UseNone'),
  useOutlines('UseOutlines'),
  useThumbs('UseThumbs'),
  fullScreen('FullScreen'),
  useOptionalContent('UseOC'),
  useAttachments('UseAttachments');

  const PageMode(this.value);

  final String value;

  static PageMode fromString(String value) {
    for (final mode in PageMode.values) {
      if (mode.value == value) {
        return mode;
      }
    }
    throw ArgumentError('Unknown page mode: $value');
  }
}

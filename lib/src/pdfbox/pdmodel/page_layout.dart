/// Defines the page layout to use when the document is opened.
enum PageLayout {
  singlePage('SinglePage'),
  oneColumn('OneColumn'),
  twoColumnLeft('TwoColumnLeft'),
  twoColumnRight('TwoColumnRight'),
  twoPageLeft('TwoPageLeft'),
  twoPageRight('TwoPageRight');

  const PageLayout(this.value);

  final String value;

  static PageLayout fromString(String value) {
    for (final layout in PageLayout.values) {
      if (layout.value == value) {
        return layout;
      }
    }
    throw ArgumentError('Unknown page layout: $value');
  }
}

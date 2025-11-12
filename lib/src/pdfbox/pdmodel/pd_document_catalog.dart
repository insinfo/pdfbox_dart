import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';
import 'common/pd_metadata.dart';
import 'common/pd_page_labels.dart';
import 'graphics/optionalcontent/pd_optional_content_properties.dart';
import 'interactive/viewerpreferences/pd_viewer_preferences.dart';
import 'page_layout.dart';
import 'page_mode.dart';
import 'pd_page_tree.dart';

/// Represents the document catalog (/Root) dictionary.
class PDDocumentCatalog {
  PDDocumentCatalog(this._document, [COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDefaultCatalog();

  final COSDocument _document;
  final COSDictionary _dictionary;
  PDPageTree? _pageTree;
  PDOptionalContentProperties? _optionalContentProperties;
  PDPageLabels? _pageLabels;
  PDViewerPreferences? _viewerPreferences;

  COSDictionary get cosObject => _dictionary;

  PDPageTree get pages {
    _pageTree ??= _createPageTree();
    return _pageTree!;
  }

  /// Returns the optional content configuration dictionary if present.
  PDOptionalContentProperties? get optionalContentProperties {
    if (_optionalContentProperties != null) {
      return _optionalContentProperties;
    }
    final dict = _dictionary.getCOSDictionary(COSName.ocProperties);
    if (dict == null) {
      return null;
    }
    _optionalContentProperties =
        PDOptionalContentProperties.fromDictionary(dict);
    return _optionalContentProperties;
  }

  set optionalContentProperties(PDOptionalContentProperties? properties) {
    _optionalContentProperties = properties;
    if (properties == null) {
      _dictionary.removeItem(COSName.ocProperties);
    } else {
      _dictionary[COSName.ocProperties] = properties.cosObject;
    }
  }

  /// Returns the document metadata stream or null if missing.
  PDMetadata? get metadata {
    final base = _dictionary.getDictionaryObject(COSName.metadata);
    if (base is COSStream) {
      return PDMetadata.fromStream(base);
    }
    return null;
  }

  set metadata(PDMetadata? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.metadata);
    } else {
      _dictionary[COSName.metadata] = value.cosStream;
    }
  }

  /// Returns the page labels dictionary if defined.
  PDPageLabels? get pageLabels {
    if (_pageLabels != null) {
      return _pageLabels;
    }
    final dict = _dictionary.getCOSDictionary(COSName.pageLabels);
    if (dict == null) {
      return null;
    }
    _pageLabels = PDPageLabels.fromDictionaryWithPageCount(
      () => pages.count,
      dict,
    );
    return _pageLabels;
  }

  set pageLabels(PDPageLabels? labels) {
    _pageLabels = labels;
    if (labels == null) {
      _dictionary.removeItem(COSName.pageLabels);
    } else {
      labels.setPageCountProvider(() => pages.count);
      _dictionary[COSName.pageLabels] = labels.cosObject;
    }
  }

  /// Returns the viewer preferences dictionary if defined.
  PDViewerPreferences? get viewerPreferences {
    final dict = _dictionary.getCOSDictionary(COSName.viewerPreferences);
    if (dict == null) {
      return null;
    }
    final current = _viewerPreferences;
    if (current == null || !identical(current.cosObject, dict)) {
      _viewerPreferences = PDViewerPreferences(dict);
    }
    return _viewerPreferences;
  }

  set viewerPreferences(PDViewerPreferences? preferences) {
    _viewerPreferences = preferences;
    if (preferences == null) {
      _dictionary.removeItem(COSName.viewerPreferences);
    } else {
      _dictionary[COSName.viewerPreferences] = preferences.cosObject;
    }
  }

  /// Returns the page layout preference for the document.
  PageLayout? get pageLayout {
    final value = _dictionary.getNameAsString(COSName.pageLayout);
    if (value == null) {
      return null;
    }
    try {
      return PageLayout.fromString(value);
    } catch (_) {
      return null;
    }
  }

  set pageLayout(PageLayout? layout) {
    if (layout == null) {
      _dictionary.removeItem(COSName.pageLayout);
    } else {
      _dictionary.setName(COSName.pageLayout, layout.value);
    }
  }

  /// Returns the initial page mode preference.
  PageMode? get pageMode {
    final value = _dictionary.getNameAsString(COSName.pageMode);
    if (value == null) {
      return null;
    }
    try {
      return PageMode.fromString(value);
    } catch (_) {
      return null;
    }
  }

  set pageMode(PageMode? mode) {
    if (mode == null) {
      _dictionary.removeItem(COSName.pageMode);
    } else {
      _dictionary.setName(COSName.pageMode, mode.value);
    }
  }

  /// Returns the document language, if specified.
  String? get language => _dictionary.getString(COSName.lang);

  set language(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.lang);
    } else {
      _dictionary.setString(COSName.lang, value);
    }
  }

  PDPageTree _createPageTree() {
    final pagesDict = _dictionary.getCOSDictionary(COSName.pages);
    if (pagesDict == null) {
      throw StateError('Document catalog is missing /Pages dictionary');
    }
    return PDPageTree(_document, pagesDict);
  }

  static COSDictionary _createDefaultCatalog() {
    final dict = COSDictionary();
    dict.setName(COSName.type, 'Catalog');
    return dict;
  }
}

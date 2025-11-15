import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import 'pd_annotation_appearance.dart';
import 'pd_border_style_dictionary.dart';

/// Base wrapper for annotation dictionaries (ISO 32000-1, §12.5).
abstract class PDAnnotation {
  PDAnnotation.internal(this.dictionary) {
    if (dictionary.getNameAsString(COSName.type) != 'Annot') {
      dictionary.setName(COSName.type, 'Annot');
    }
    _annotationCache[dictionary] = this;
  }

  static final Expando<PDAnnotation> _annotationCache =
      Expando<PDAnnotation>('pdfbox_annotation_cache');

  static PDAnnotation? getCached(COSDictionary dictionary) =>
      _annotationCache[dictionary];

  final COSDictionary dictionary;
  PDAppearanceDictionary? _appearanceCache;
  PDBorderStyleDictionary? _borderStyleCache;

  COSDictionary get cosObject => dictionary;

  String? get subtype => dictionary.getNameAsString(COSName.subtype);

  /// Returns the annotation rectangle (`/Rect`) if set.
  List<double>? get rect {
    final array = dictionary.getCOSArray(COSName.rect);
    if (array == null) {
      return null;
    }
    final values = array.toDoubleList();
    if (values.length < 4) {
      return null;
    }
    return List<double>.unmodifiable(values.take(4));
  }

  set rect(List<double>? value) {
    if (value == null) {
      dictionary.removeItem(COSName.rect);
      return;
    }
    if (value.length != 4) {
      throw ArgumentError.value(
        value,
        'value',
        'Annotation rectangle must contain exactly four coordinates',
      );
    }
    final array = COSArray()
      ..add(COSFloat(value[0].toDouble()))
      ..add(COSFloat(value[1].toDouble()))
      ..add(COSFloat(value[2].toDouble()))
      ..add(COSFloat(value[3].toDouble()));
    dictionary.setItem(COSName.rect, array);
  }

  /// Returns the raw COS representation.
  COSBase get cosBase => dictionary;

  List<double>? get color {
    final array = dictionary.getCOSArray(COSName.c);
    if (array == null) {
      return null;
    }
    final values = array.toDoubleList();
    if (values.isEmpty) {
      return null;
    }
    return List<double>.unmodifiable(values);
  }

  set color(List<double>? value) {
    if (value == null) {
      dictionary.removeItem(COSName.c);
      return;
    }
    if (value.isEmpty || (value.length != 1 && value.length != 3 && value.length != 4)) {
      throw ArgumentError.value(
        value,
        'value',
        'Annotation color must be 1, 3, or 4 components',
      );
    }
    final array = COSArray();
    for (final component in value) {
      array.add(COSFloat(component.toDouble()));
    }
    dictionary.setItem(COSName.c, array);
  }

  String? get contents => dictionary.getString(COSName.contents);

  set contents(String? value) => dictionary.setString(COSName.contents, value);

  PDAppearanceDictionary? get appearance {
    final cached = _appearanceCache;
    if (cached != null) {
      return cached;
    }
    final dict = dictionary.getCOSDictionary(COSName.appearance);
    if (dict == null) {
      return null;
    }
    final appearance = PDAppearanceDictionary(dict);
    _appearanceCache = appearance;
    return appearance;
  }

  set appearance(PDAppearanceDictionary? value) {
    _appearanceCache = value;
    if (value == null) {
      dictionary.removeItem(COSName.appearance);
    } else {
      dictionary.setItem(COSName.appearance, value);
    }
  }

  String? get appearanceState =>
      dictionary.getNameAsString(COSName.appearanceState);

  set appearanceState(String? value) {
    if (value == null) {
      dictionary.removeItem(COSName.appearanceState);
    } else {
      dictionary.setName(COSName.appearanceState, value);
    }
  }

  PDBorderStyleDictionary? get borderStyle {
    final cached = _borderStyleCache;
    if (cached != null) {
      return cached;
    }
    final dict = dictionary.getCOSDictionary(COSName.bs);
    if (dict == null) {
      return null;
    }
    final border = PDBorderStyleDictionary(dict);
    _borderStyleCache = border;
    return border;
  }

  set borderStyle(PDBorderStyleDictionary? value) {
    _borderStyleCache = value;
    if (value == null) {
      dictionary.removeItem(COSName.bs);
    } else {
      dictionary.setItem(COSName.bs, value);
    }
  }
}

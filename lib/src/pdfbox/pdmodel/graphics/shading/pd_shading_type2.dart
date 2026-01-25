part of 'pd_shading.dart';

/// Resources for an axial shading (ShadingType=2).
class PDShadingType2 extends PDShading {
  PDShadingType2(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  COSArray? _coords;
  COSArray? _domain;
  COSArray? _extend;
  PDFunction? _function;

  COSArray? get coords => _coords ??= cosObject.getCOSArray(COSName.coords);

  COSArray? get domain => _domain ??= cosObject.getCOSArray(COSName.domain);

  COSArray? get extend => _extend ??= cosObject.getCOSArray(COSName.extend);

  PDFunction? get function {
    if (_function != null) {
      return _function;
    }
    final COSBase? base = cosObject.getDictionaryObject(COSName.function);
    if (base == null) {
      return null;
    }
    _function = PDFunction.create(base);
    return _function;
  }

  List<double>? evalFunction(double t) {
    final fn = function;
    if (fn == null) {
      return null;
    }
    return fn.eval(<double>[t]);
  }
}


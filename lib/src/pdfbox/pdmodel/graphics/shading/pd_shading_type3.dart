part of 'pd_shading.dart';

/// Resources for a radial shading (ShadingType=3).
class PDShadingType3 extends PDShading {
  PDShadingType3(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  COSArray? _coords;
  COSArray? _domain;
  COSArray? _extend;

  /// Underlying function definition.
  COSBase? _functionBase;

  COSArray? get coords => _coords ??= cosObject.getCOSArray(COSName.coords);

  COSArray? get domain => _domain ??= cosObject.getCOSArray(COSName.domain);

  COSArray? get extend => _extend ??= cosObject.getCOSArray(COSName.extend);

  COSBase? get functionBase =>
      _functionBase ??= cosObject.getDictionaryObject(COSName.function);

  List<double>? evalFunction(double t) {
    final base = functionBase;
    if (base == null) {
      return null;
    }

    // Spec allows /Function to be a single function or an array of functions.
    if (base is COSArray) {
      final out = <double>[];
      for (var i = 0; i < base.length; i++) {
        final fn = PDFunction.create(base.getObject(i));
        final values = fn.eval(<double>[t]);
        out.addAll(values);
      }
      return out;
    }

    final fn = PDFunction.create(base);
    return fn.eval(<double>[t]);
  }
}


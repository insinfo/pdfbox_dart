part of 'pd_shading.dart';

/// Resources for a function-based shading (ShadingType=1).
///
/// Type 1 shadings define the color at each point by a color function that
/// takes the (x, y) coordinates as input and produces color components as output.
class PDShadingType1 extends PDShading {
  PDShadingType1(COSDictionary dictionary, {dynamic resources})
      : super(dictionary, resources: resources);

  COSArray? _domain;
  Matrix? _matrix;

  /// Gets the optional Matrix for this function-based shading.
  /// Returns identity if not defined.
  Matrix get matrix {
    if (_matrix != null) {
      return _matrix!;
    }
    final matrixArray = cosObject.getCOSArray(COSName.matrix);
    if (matrixArray != null) {
      _matrix = Matrix.fromCos(matrixArray);
    } else {
      _matrix = Matrix();
    }
    return _matrix!;
  }

  /// Sets the matrix for this function-based shading.
  void setMatrix(Matrix m) {
    _matrix = m;
    final array = COSArray();
    array.add(COSFloat(m.scaleX));
    array.add(COSFloat(m.shearY));
    array.add(COSFloat(m.shearX));
    array.add(COSFloat(m.scaleY));
    array.add(COSFloat(m.translateX));
    array.add(COSFloat(m.translateY));
    cosObject.setItem(COSName.matrix, array);
  }

  /// Gets the optional Domain values.
  /// An array of four numbers [xmin xmax ymin ymax] specifying the rectangular
  /// domain of coordinates over which the color function(s) are defined.
  /// Default value: [0.0 1.0 0.0 1.0].
  COSArray? get domain => _domain ??= cosObject.getCOSArray(COSName.domain);

  /// Sets the domain for this function-based shading.
  void setDomain(COSArray newDomain) {
    _domain = newDomain;
    cosObject.setItem(COSName.domain, newDomain);
  }

  /// Gets the domain as a list of doubles.
  /// Returns [0.0, 1.0, 0.0, 1.0] if not defined.
  List<double> get domainValues {
    final d = domain;
    if (d == null || d.length < 4) {
      return <double>[0.0, 1.0, 0.0, 1.0];
    }
    return <double>[
      d.getDouble(0) ?? 0.0,
      d.getDouble(1) ?? 1.0,
      d.getDouble(2) ?? 0.0,
      d.getDouble(3) ?? 1.0,
    ];
  }

  /// Evaluates all functions at the input values.
  /// Returns the output color components, or null if no function defined.
  List<double>? evalFunction(List<double> input) {
    final base = cosObject.getDictionaryObject(COSName.function);
    if (base == null) {
      return null;
    }

    // Spec allows /Function to be a single function or an array of functions.
    if (base is COSArray) {
      final out = <double>[];
      for (var i = 0; i < base.length; i++) {
        final fn = PDFunction.create(base.getObject(i));
        final values = fn.eval(input);
        out.addAll(values);
      }
      return out;
    }

    final fn = PDFunction.create(base);
    return fn.eval(input);
  }
}


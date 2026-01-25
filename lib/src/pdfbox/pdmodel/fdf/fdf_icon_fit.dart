import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_float.dart';

/// This represents an Icon fit dictionary for an FDF field.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFIconFit
class FDFIconFit implements COSObjectable {
  FDFIconFit([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  /// A scale option: Always scale.
  static const String scaleOptionAlways = 'A';
  
  /// A scale option: Only when icon is bigger.
  static const String scaleOptionOnlyWhenIconIsBigger = 'B';
  
  /// A scale option: Only when icon is smaller.
  static const String scaleOptionOnlyWhenIconIsSmaller = 'S';
  
  /// A scale option: Never scale.
  static const String scaleOptionNever = 'N';

  /// Scale to fill width of annotation, disregarding aspect ratio.
  static const String scaleTypeAnamorphic = 'A';
  
  /// Scale to fit width or height, smaller of two, while retaining aspect ratio.
  static const String scaleTypeProportional = 'P';

  @override
  COSDictionary get cosObject => _dictionary;

  /// This will get the scale option. See the scaleOption constants. 
  /// This is guaranteed to never return null. Default: Always
  /// Returns the scale option.
  String get scaleOption {
    return _dictionary.getNameAsString(COSName.sw) ?? scaleOptionAlways;
  }

  /// This will set the scale option for the icon. Use the scaleOption constants.
  /// [option] The scale option.
  set scaleOption(String option) {
    _dictionary.setName(COSName.sw, option);
  }

  /// This will get the scale type. See the scaleType constants. 
  /// This is guaranteed to never return null. Default: Proportional
  /// Returns the scale type.
  String get scaleType {
    return _dictionary.getNameAsString(COSName.s) ?? scaleTypeProportional;
  }

  /// This will set the scale type. Use the scaleType constants.
  /// [scale] The scale type.
  set scaleType(String scale) {
    _dictionary.setName(COSName.s, scale);
  }

  /// This is guaranteed to never return null.
  /// An array of two numbers between 0.0 and 1.0 indicating the fraction of leftover 
  /// space to allocate at the left and bottom of the icon. A value of [0.0, 0.0] 
  /// positions the icon at the bottom-left corner of the annotation rectangle; 
  /// a value of [0.5, 0.5] centers it within the rectangle. This entry is used only 
  /// if the icon is scaled proportionally. Default value: [0.5, 0.5].
  /// Returns the fractional space to allocate [left, bottom].
  List<double> get fractionalSpaceToAllocate {
    final array = _dictionary.getCOSArray(COSName.a);
    if (array == null || array.length < 2) {
      return [0.5, 0.5];
    }
    return [
      array.getDouble(0) ?? 0.5,
      array.getDouble(1) ?? 0.5,
    ];
  }

  /// This will set fractional space to allocate.
  /// [space] The space to allocate [left, bottom].
  set fractionalSpaceToAllocate(List<double> space) {
    if (space.length < 2) {
      throw ArgumentError('Fractional space must have 2 elements');
    }
    final array = COSArray();
    array.addObject(COSFloat(space[0]));
    array.addObject(COSFloat(space[1]));
    _dictionary.setItem(COSName.a, array);
  }

  /// This will tell if the icon should scale to fit the annotation bounds. 
  /// Default: false
  /// Returns a flag telling if the icon should scale.
  bool get shouldScaleToFitAnnotation {
    return _dictionary.getBoolean(COSName.fb) ?? false;
  }

  /// This will tell the icon to scale.
  /// [value] The flag value.
  set shouldScaleToFitAnnotation(bool value) {
    _dictionary.setBoolean(COSName.fb, value);
  }
}


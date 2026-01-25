import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This represents a Ink FDF annotation.
class FDFAnnotationInk extends FDFAnnotation {
  /// COS Model value for SubType entry.
  static const String SUBTYPE = 'Ink';

  /// Default constructor.
  FDFAnnotationInk() : super() {
    annot.setName(COSName.subtype, SUBTYPE);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationInk.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Set the paths making up the freehand "scribble".
  ///
  /// The ink annotation is made up of one ore more disjoint paths. Each array entry is an array representing a stroked
  /// path, being a series of alternating horizontal and vertical coordinates in default user space.
  ///
  /// [inklist] the List of arrays representing the paths.
  void setInkList(List<List<double>> inklist) {
    COSArray newInklist = COSArray();
    for (List<double> array in inklist) {
      newInklist.add(COSArray(array.map((e) => COSFloat(e)).toList()));
    }
    annot.setItem(COSName.inkList, newInklist);
  }

  /// Get the paths making up the freehand "scribble".
  ///
  /// Returns the List of arrays representing the paths.
  List<List<double>>? getInkList() {
    COSArray? array = annot.getCOSArray(COSName.inkList);
    if (array != null) {
      List<List<double>> retval = [];
      for (COSBase entry in array) {
        if (entry is COSArray) {
          retval.add(entry.toDoubleList());
        }
      }
      return retval;
    } else {
      return null;
    }
  }
}

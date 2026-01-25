import '../../../utils/xml/xml.dart';
import '../../cos/cos_array.dart';

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
    annot.setItem(COSName.subtype, COSName.ink);
  }

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationInk.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationInk.fromXml(XmlElement element) : super.fromXml(element) {
    annot.setItem(COSName.subtype, COSName.ink);
  }

  /// Set the paths making up the freehand "scribble".
  void setInkList(List<List<double>> inkList) {
    COSArray newInkList = COSArray();
    for (List<double> path in inkList) {
      COSArray newPath = COSArray();
      for(double d in path) {
        newPath.add(COSFloat(d));
      }
      newInkList.add(newPath);
    }
    annot.setItem(COSName.inkList, newInkList);
  }

  /// Get the paths making up the freehand "scribble".
  List<List<double>>? getInkList() {
    COSArray? inkList = annot.getCOSArray(COSName.inkList);
    if (inkList != null) {
      List<List<double>> retval = [];
      for (int i = 0; i < inkList.length; i++) {
        COSArray? path = inkList.getObject(i) as COSArray?;
        if (path != null) {
           retval.add(path.toDoubleList());
        }
      }
      return retval;
    }
    return null;
  }
}


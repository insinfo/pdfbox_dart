import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_float.dart';
import '../../cos/cos_name.dart';
import 'fdf_annotation.dart';

/// This abstract class is used as a superclass for the different FDF annotations with text markup attributes.
abstract class FDFAnnotationTextMarkup extends FDFAnnotation {
  /// Default constructor.
  FDFAnnotationTextMarkup() : super();

  /// Constructor.
  ///
  /// [a] An existing FDF Annotation.
  FDFAnnotationTextMarkup.fromDictionary(COSDictionary a) : super.fromDictionary(a);

  /// Constructor from XML Element.
  FDFAnnotationTextMarkup.fromXml(XmlElement element) : super.fromXml(element) {
    String? nums = element.getAttribute('coords');
    if (nums != null) {
        List<double> values = [];
        for(String s in nums.split(',')) {
            values.add(double.parse(s));
        }
        setCoords(values);
    }
  }

  /// Set the coordinates of individual words or group of words.
  ///
  /// The quadliterals shall encompasses a word or group of contiguous words in the text underlying the annotation. The
  /// coordinates for each quadrilateral shall be given in the order x1 y1 x2 y2 x3 y3 x4 y4.
  ///
  /// [coords] an array of 8 * n numbers specifying the coordinates of n quadrilaterals.
  void setCoords(List<double> coords) {
    annot.setItem(COSName.quadPoints, COSArray(coords.map((e) => COSFloat(e)).toList()));
  }

  /// Get the coordinates of individual words or group of words.
  ///
  /// Returns the array of 8 * n numbers specifying the coordinates of n quadrilaterals.
  List<double>? getCoords() {
    COSArray? quadPoints = annot.getCOSArray(COSName.quadPoints);
    if (quadPoints != null) {
      return quadPoints.toDoubleList();
    } else {
      return null;
    }
  }
}


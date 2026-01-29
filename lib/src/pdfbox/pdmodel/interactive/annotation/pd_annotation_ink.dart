import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_float.dart';
import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import 'pd_annotation_markup.dart';

/// This is the class that represents a Ink annotation.
class PDAnnotationInk extends PDAnnotationMarkup {
  /// The type of annotation.
  static const String subType = 'Ink';

  /// Constructor.
  PDAnnotationInk([COSDictionary? field])
      : super(field ?? COSDictionary()) {
    if (field == null) {
      dictionary.setName(COSName.subtype, subType);
    }
  }

  /// Sets the paths that make this annotation.
  ///
  /// [inkList] An array of arrays, each representing a stroked path. Each array shall be a
  /// series of alternating horizontal and vertical coordinates. If the parameter is null the entry
  /// will be removed.
  void setInkList(List<List<double>>? inkList) {
    if (inkList == null) {
      dictionary.removeItem(COSName.inkList);
      return;
    }
    final array = COSArray();
    for (final path in inkList) {
      final pathArray = COSArray();
      for (final f in path) {
        pathArray.add(COSFloat(f));
      }
      array.add(pathArray);
    }
    dictionary.setItem(COSName.inkList, array);
  }

  /// Get one or more disjoint paths that make this annotation.
  ///
  /// Returns An array of arrays, each representing a stroked path. Each array shall be a series of
  /// alternating horizontal and vertical coordinates.
  List<List<double>> getInkList() {
    final array = dictionary.getCOSArray(COSName.inkList);
    if (array != null) {
      final result = <List<double>>[];
      for (var i = 0; i < array.length; ++i) {
        final base2 = array.getObject(i);
        if (base2 is COSArray) {
          result.add(base2.toDoubleList());
        } else {
          result.add(<double>[]);
        }
      }
      return result;
    }
    return <List<double>>[];
  }

  // TODO: setCustomAppearanceHandler, constructAppearances
  void constructAppearances([PDDocument? document]) {
    // Implement PDInkAppearanceHandler logic when handlers are ported
  }
}

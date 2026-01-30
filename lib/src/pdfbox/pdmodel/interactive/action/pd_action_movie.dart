import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

import 'pd_action.dart';

/// This represents a Movie action that can be executed in a PDF document.
class PDActionMovie extends PDAction {
  /// This type of action this object represents.
  static const String subType = 'Movie';

  /// Default constructor.
  PDActionMovie() {
    setSubType(subType);
  }

  /// Constructor from an existing dictionary.
  PDActionMovie.fromDictionary(COSDictionary a) : super.fromDictionary(a);
  
  /// The title of the movie action.
  String? getT() {
    return dictionary.getString(COSName.t);
  }

  /// Sets the title of the movie action.
  void setT(String title) {
    dictionary.setString(COSName.t, title);
  }

  /// The operation to perform on the movie.
  /// (Play, Stop, Pause, Resume)
  String? getOperation() {
    return dictionary.getNameAsString(COSName.operation);
  }

  /// Sets the operation to perform on the movie.
  void setOperation(String operation) {
    dictionary.setName(COSName.operation, operation);
  }

  /// The annotation to be played.
  COSDictionary? getAnnotation() {
    return dictionary.getCOSDictionary(COSName.annotation);
  }

  /// Sets the annotation to be played.
  void setAnnotation(COSDictionary annotation) {
    dictionary.setItem(COSName.annotation, annotation);
  }
}

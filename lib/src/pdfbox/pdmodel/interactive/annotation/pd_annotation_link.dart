import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../../cos/cos_string.dart';
import '../../common/pd_destination.dart';
import '../action/pd_action.dart';
import '../action/pd_action_factory.dart';
import 'pd_annotation.dart';

/// Link annotation wrapper supporting destinations and actions.
class PDAnnotationLink extends PDAnnotation {
  factory PDAnnotationLink({COSDictionary? dictionary}) {
    final dict = dictionary ?? COSDictionary();
    final cached = PDAnnotation.getCached(dict);
    if (cached is PDAnnotationLink) {
      return cached;
    }
    if (dict.getNameAsString(COSName.subtype) != 'Link') {
      dict.setName(COSName.subtype, 'Link');
    }
    return PDAnnotationLink._(dict);
  }

  factory PDAnnotationLink.fromDictionary(COSDictionary dictionary) {
    final cached = PDAnnotation.getCached(dictionary);
    if (cached is PDAnnotationLink) {
      return cached;
    }
    if (dictionary.getNameAsString(COSName.subtype) != 'Link') {
      dictionary.setName(COSName.subtype, 'Link');
    }
    return PDAnnotationLink._(dictionary);
  }

  PDAnnotationLink._(COSDictionary dictionary) : super.internal(dictionary);

  PDDestination? get destination =>
      PDDestination.fromCOS(cosObject.getDictionaryObject(COSName.dest));

  set destination(PDDestination? value) =>
      cosObject.setItem(COSName.dest, value?.cosObject);

  String? get destinationName {
    final base = cosObject.getDictionaryObject(COSName.dest);
    if (base is COSName) {
      return base.name;
    }
    if (base is COSString) {
      return base.string;
    }
    if (base is COSObject) {
      final deref = base.object;
      if (deref is COSName) {
        return deref.name;
      }
      if (deref is COSString) {
        return deref.string;
      }
    }
    return null;
  }

  set destinationName(String? value) {
    if (value == null) {
      cosObject.removeItem(COSName.dest);
    } else {
      cosObject.setString(COSName.dest, value);
    }
  }

  PDAction? get action =>
      PDActionFactory.instance
          .createAction(cosObject.getDictionaryObject(COSName.a));

  set action(PDAction? value) =>
      cosObject.setItem(COSName.a, value?.cosObject);
}

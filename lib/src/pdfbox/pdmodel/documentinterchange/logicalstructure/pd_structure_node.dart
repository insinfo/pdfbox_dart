import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_integer.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../common/cos_array_list.dart';
import 'pd_structure_element.dart';
import 'pd_structure_tree_root.dart';
import 'pd_object_reference.dart';
import 'pd_marked_content_reference.dart';

abstract class PDStructureNode implements COSObjectable {
  final COSDictionary _dictionary;

  PDStructureNode(String type) : _dictionary = COSDictionary() {
    _dictionary[COSName.type] = COSName(type);
  }

  PDStructureNode.fromDictionary(this._dictionary);

  static PDStructureNode create(COSDictionary node) {
    final type = node.getNameAsString(COSName.type);
    if ('StructTreeRoot' == type) {
      return PDStructureTreeRoot(node);
    }
    if (type == null || 'StructElem' == type) {
      return PDStructureElement(node);
    }
    throw ArgumentError(
        "Dictionary must not include a Type entry with a value that is neither StructTreeRoot nor StructElem.");
  }

  @override
  COSDictionary get cosObject => _dictionary;

  String? getType() {
    return _dictionary.getNameAsString(COSName.type);
  }

  List<Object> getKids() {
    final kidObjects = <Object>[];
    final k = _dictionary.getDictionaryObject(COSName.k);
    if (k is COSArray) {
      for (final kid in k) {
        final kidObject = createObject(kid);
        if (kidObject != null) {
          kidObjects.add(kidObject);
        }
      }
    } else if (k != null) {
      final kidObject = createObject(k);
      if (kidObject != null) {
        kidObjects.add(kidObject);
      }
    }
    return kidObjects;
  }

  void setKids(List<Object> kids) {
    _dictionary[COSName.k] = COSArrayList.converterToCOSArray(kids);
  }

  void appendKid(PDStructureElement structureElement) {
    appendObjectableKid(structureElement);
    structureElement.setParent(this);
  }

  void appendObjectableKid(COSObjectable? objectable) {
    if (objectable == null) {
      return;
    }
    appendKidBase(objectable.cosObject);
  }

  void appendKidBase(COSBase? object) {
    if (object == null) {
      return;
    }
    final k = _dictionary.getDictionaryObject(COSName.k);
    if (k == null) {
      _dictionary[COSName.k] = object;
    } else if (k is COSArray) {
      k.add(object);
    } else {
      final array = COSArray();
      array.add(k);
      array.add(object);
      _dictionary[COSName.k] = array;
    }
  }

  Object? createObject(COSBase kid) {
    COSDictionary? kidDic;
    if (kid is COSDictionary) {
      kidDic = kid;
    } else if (kid is COSObject) {
      final base = kid.object;
      if (base is COSDictionary) {
        kidDic = base;
      }
    }
    if (kidDic != null) {
      return createObjectFromDic(kidDic);
    } else if (kid is COSInteger) {
      return kid.intValue;
    }
    return null;
  }

  COSObjectable? createObjectFromDic(COSDictionary kidDic) {
    final type = kidDic.getNameAsString(COSName.type);
    if (type == null) {
      return PDStructureElement(kidDic);
    }
    switch (type) {
      case PDStructureElement.TYPE:
        return PDStructureElement(kidDic);
      case PDObjectReference.TYPE:
        return PDObjectReference(kidDic);
      case PDMarkedContentReference.TYPE:
        return PDMarkedContentReference(kidDic);
      default:
        return null;
    }
  }
}

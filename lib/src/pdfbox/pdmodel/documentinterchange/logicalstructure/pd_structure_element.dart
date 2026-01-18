import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_integer.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_object.dart';
import '../../pd_page.dart';
import 'pd_attribute_object.dart';
import 'pd_structure_node.dart';
import 'revisions.dart';

class PDStructureElement extends PDStructureNode {
  static const String TYPE = 'StructElem';

  PDStructureElement(COSDictionary dictionary) : super.fromDictionary(dictionary);

  PDStructureElement.create(String structureType, PDStructureNode parent) : super(TYPE) {
    setStructureType(structureType);
    setParent(parent);
  }

  String? getStructureType() {
    return cosObject.getNameAsString(COSName.s);
  }

  void setStructureType(String structureType) {
    cosObject.setName(COSName.s, structureType);
  }

  PDStructureNode? getParent() {
    final parent = cosObject.getDictionaryObject(COSName.p);
    if (parent is COSDictionary) {
      return PDStructureNode.create(parent);
    }
    return null;
  }

  void setParent(PDStructureNode? structureNode) {
    cosObject[COSName.p] = structureNode;
  }

  /// Returns the page object (`/Pg`) this structure element belongs to, if any.
  PDPage? getPage() {
    final base = cosObject.getDictionaryObject(COSName.pg);
    if (base is COSDictionary) {
      return PDPage(base);
    }
    return null;
  }

  void setPage(PDPage? page) {
    cosObject[COSName.pg] = page;
  }

  /// Returns the structure element identifier (`/ID`) when present.
  String? getId() => cosObject.getString(COSName.id);

  void setId(String? id) => cosObject.setString(COSName.id, id);

  /// Returns the language (`/Lang`) when present.
  String? getLanguage() => cosObject.getString(COSName.lang);

  void setLanguage(String? language) => cosObject.setString(COSName.lang, language);

  /// Returns alternate description (`/Alt`) when present.
  String? getAlternateDescription() => cosObject.getString(COSName.alt);

  void setAlternateDescription(String? alt) => cosObject.setString(COSName.alt, alt);

  /// Returns the replacement text (`/ActualText`) when present.
  String? getActualText() => cosObject.getString(COSName.actualText);

  void setActualText(String? actualText) =>
      cosObject.setString(COSName.actualText, actualText);

  Revisions<PDAttributeObject> getAttributes() {
    final attributes = Revisions<PDAttributeObject>();
    final base = cosObject.getDictionaryObject(COSName.a);
    if (base is COSArray) {
      PDAttributeObject? current;
      for (var i = 0; i < base.length; i++) {
        final item = base.getObject(i);
        if (item is COSDictionary) {
          current = PDAttributeObject.create(item);
          current.setStructureElement(this);
          attributes.addObject(current, 0);
        } else if (item is COSInteger && current != null) {
          attributes.setRevisionNumber(current, item.intValue);
        }
      }
    } else if (base is COSDictionary) {
      final attribute = PDAttributeObject.create(base);
      attribute.setStructureElement(this);
      attributes.addObject(attribute, 0);
    }
    return attributes;
  }

  void setAttributes(Revisions<PDAttributeObject> attributes) {
    if (attributes.size == 1 && attributes.getRevisionNumber(0) == 0) {
      final attribute = attributes.getObject(0);
      attribute.setStructureElement(this);
      cosObject.setItem(COSName.a, attribute);
      return;
    }
    final array = COSArray();
    for (var i = 0; i < attributes.size; i++) {
      final attribute = attributes.getObject(i);
      final revisionNumber = attributes.getRevisionNumber(i);
      if (revisionNumber < 0) {
        throw ArgumentError('The revision number shall be > -1');
      }
      attribute.setStructureElement(this);
      array.add(attribute);
      array.add(COSInteger.valueOf(revisionNumber));
    }
    cosObject.setItem(COSName.a, array);
  }

  void addAttribute(PDAttributeObject attributeObject) {
    attributeObject.setStructureElement(this);
    final existing = cosObject.getDictionaryObject(COSName.a);
    COSArray array;
    if (existing is COSArray) {
      array = existing;
    } else {
      array = COSArray();
      if (existing != null) {
        array.addObject(existing);
        array.add(COSInteger.valueOf(0));
      }
      cosObject.setItem(COSName.a, array);
    }
    array.add(attributeObject);
    array.add(COSInteger.valueOf(revisionNumber));
  }

  void removeAttribute(PDAttributeObject attributeObject) {
    final existing = cosObject.getDictionaryObject(COSName.a);
    if (existing is COSArray) {
      existing.remove(attributeObject.cosObject);
      if (existing.length == 2 && existing.getInt(1, 0) == 0) {
        cosObject.setItem(COSName.a, existing.getObject(0));
      }
    } else {
      var direct = existing;
      if (direct is COSObject) {
        direct = direct.object;
      }
      if (attributeObject.cosObject == direct) {
        cosObject.setItem(COSName.a, null);
      }
    }
    attributeObject.setStructureElement(null);
  }

  void attributeChanged(PDAttributeObject attributeObject) {
    final existing = cosObject.getDictionaryObject(COSName.a);
    if (existing is COSArray) {
      for (var i = 0; i < existing.length; i++) {
        final entry = existing.getObject(i);
        if (entry == attributeObject.cosObject) {
          final next = existing.getObject(i + 1);
          if (next is COSInteger) {
            existing[i + 1] = COSInteger.valueOf(revisionNumber);
          }
        }
      }
    } else if (existing != null) {
      final array = COSArray(<COSBase>[
        existing,
        COSInteger.valueOf(revisionNumber),
      ]);
      cosObject.setItem(COSName.a, array);
    }
  }

  int get revisionNumber => cosObject.getInt(COSName.r, 0) ?? 0;

  set revisionNumber(int value) {
    if (value < 0) {
      throw ArgumentError('The revision number shall be > -1');
    }
    cosObject.setInt(COSName.r, value);
  }

  void incrementRevisionNumber() {
    revisionNumber = revisionNumber + 1;
  }
}

part of pdfbox.pdmodel.property_list;

/// Represents an optional content membership dictionary (OCMD).
class PDOptionalContentMembershipDictionary extends PDPropertyList {
  PDOptionalContentMembershipDictionary() : super() {
    dict[COSName.type] = COSName.ocmd;
  }

  PDOptionalContentMembershipDictionary.fromDictionary(COSDictionary dictionary)
      : super(dictionary: dictionary) {
    final type = dictionary.getDictionaryObject(COSName.type);
    if (type != COSName.ocmd) {
      throw ArgumentError(
        "Provided dictionary is not of type '${COSName.ocmd.name}'",
      );
    }
  }

  /// Returns the optional content groups referenced by this membership dictionary.
  List<PDPropertyList> get ocgs {
    final base = dict.getDictionaryObject(COSName.ocgs);
    if (base is COSDictionary) {
      return <PDPropertyList>[PDPropertyList.create(base)];
    }
    if (base is COSArray) {
      final result = <PDPropertyList>[];
      for (var i = 0; i < base.length; ++i) {
        final element = _dereference(base.getObject(i));
        if (element is COSDictionary) {
          result.add(PDPropertyList.create(element));
        }
      }
      return List<PDPropertyList>.unmodifiable(result);
    }
    return const <PDPropertyList>[];
  }

  /// Sets the optional content groups referenced by this membership dictionary.
  set ocgs(List<PDPropertyList> groups) {
    final array = COSArray();
    for (final group in groups) {
      array.add(group);
    }
    dict[COSName.ocgs] = array;
  }

  /// Returns the visibility policy (/P) for this membership dictionary.
  COSName get visibilityPolicy => dict.getCOSName(COSName.p) ?? COSName.anyOn;

  set visibilityPolicy(COSName value) {
    dict[COSName.p] = value;
  }

  COSBase? _dereference(COSBase? base) {
    if (base is COSObject) {
      return base.object;
    }
    return base;
  }
}

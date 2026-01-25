import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_float.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_object.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_string.dart';
import '../pdmodel/pd_document.dart';

/// Utility class used to clone COS objects.
class PDFCloneUtility {
  final PDDocument _destination;
  final Map<COSObject, COSBase> _clonedVersion = {};

  PDFCloneUtility(this._destination);

  /// Returns the destination document.
  PDDocument get destination => _destination;

  /// Returns the cloned version of a source object if it has been cloned methods.
  COSBase? getClonedObject(COSObject source) => _clonedVersion[source];

  /// Clones the given COSBase object to the destination document.
  COSBase? cloneForNewDocument(COSBase? base) {
    if (base == null) {
      return null;
    }

    if (base is COSObject) {
      return _cloneCOSObject(base);
    }

    if (base is COSArray) {
      final newArray = COSArray();
      for (int i = 0; i < base.length; i++) {
        newArray.add(cloneForNewDocument(base.getObject(i))!);
      }
      return newArray;
    }

    if (base is COSStream) {
      final newStream = COSStream();
      // Copy dictionary items
      for (final entry in base.entries) {
        newStream[entry.key] = cloneForNewDocument(entry.value);
      }
      // Copy stream data
      final bytes = base.encodedBytes();
      if (bytes != null) {
          newStream.data = bytes;
      }
      return newStream;
    }

    if (base is COSDictionary) {
      final newDict = COSDictionary();
      for (final entry in base.entries) {
        newDict[entry.key] = cloneForNewDocument(entry.value);
      }
      return newDict;
    }

    // Primitive types are immutable or can be shared/copied easily
    if (base is COSString) {
      return COSString(base.string); // Or clone bytes if hex
    }
    if (base is COSName) {
      return base; // COSName is shared/immutable
    }
    if (base is COSInteger) {
      return COSInteger(base.intValue);
    }
    if (base is COSFloat) {
      return COSFloat(base.doubleValue);
    }
    if (base is COSBoolean) {
      return base;
    }
    if (base is COSNull) {
      return base;
    }

    throw UnsupportedError('Unknown COS type: ${base.runtimeType}');
  }

  COSBase _cloneCOSObject(COSObject original) {
    if (_clonedVersion.containsKey(original)) {
      return _clonedVersion[original]!;
    }

    final actual = original.object;
    if (actual is COSNull) {
        return COSNull.instance;
    }

    // Create a new indirect object in the destination document
    // We pass null initially to reserve the object number, then set the value later
    // to handle recursion.
    
    final clonedObject = _destination.cosDocument.createObject(null);
    _clonedVersion[original] = clonedObject;
    
    final clonedValue = cloneForNewDocument(actual);
    clonedObject.object = clonedValue!; 
    
    return clonedObject;
  }
  
  /// Clones a COSBase and ensures it is registered as an indirect object in the destination.
  COSObject cloneAndRegister(COSBase base) {
      final cloned = cloneForNewDocument(base);
      if (cloned is COSObject) {
          return cloned;
      }
      return _destination.cosDocument.createObject(cloned);
  }

  /// Merges two objects.
  void cloneMerge(dynamic base, dynamic target) {
    if (base == null || target == null) {
      return;
    }
    
    COSBase? baseCOS = _toCOSBase(base);
    COSBase? targetCOS = _toCOSBase(target);

    if (baseCOS is COSDictionary && targetCOS is COSDictionary) {
      for (final entry in baseCOS.entries) {
        final key = entry.key;
        final value = entry.value;
        if (targetCOS[key] == null) {
          targetCOS[key] = cloneForNewDocument(value);
        }
      }
    }
  }

  COSBase? _toCOSBase(dynamic object) {
    if (object is COSBase) {
      return object;
    }
    // Check for cosObject getter
    try {
      return (object as dynamic).cosObject as COSBase?;
    } catch (_) {
      return null;
    }
  }
}


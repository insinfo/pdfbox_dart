import 'cos_base.dart';
import 'cos_dictionary.dart';
import 'cos_object.dart';
import 'cos_object_key.dart';

class COSDocument {
  COSDocument();

  final Map<COSObjectKey, COSObject> _objects = <COSObjectKey, COSObject>{};
  final COSDictionary trailer = COSDictionary();

  bool _closed = false;

  Iterable<COSObject> get objects => _objects.values;

  COSObject? getObject(COSObjectKey key) => _objects[key];

  COSObject? getObjectByNumber(int objectNumber, [int generationNumber = 0]) =>
      getObject(COSObjectKey(objectNumber, generationNumber));

  void addObject(COSObject object) {
    if (_closed) {
      throw StateError('COSDocument is closed');
    }
    _objects[object.key] = object;
  }

  COSObject createObject([COSBase? value]) {
    final objectNumber = _objects.length + 1;
    final obj = COSObject(objectNumber, 0, value);
    addObject(obj);
    return obj;
  }

  void removeObject(COSObject object) {
    _objects.remove(object.key);
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _objects.clear();
    trailer.clear();
  }

  bool get isClosed => _closed;
}

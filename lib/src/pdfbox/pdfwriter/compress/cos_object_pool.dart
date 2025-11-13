import '../../cos/cos_base.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_object_key.dart';

class COSObjectPool {
  COSObjectPool([this._highestXRefObjectNumber = 0]);

  final Map<COSObjectKey, COSBase> _keyPool = <COSObjectKey, COSBase>{};
  final Map<COSBase, COSObjectKey> _objectPool = <COSBase, COSObjectKey>{};

  int _highestXRefObjectNumber;

  COSObjectKey? put(COSObjectKey? key, COSBase? object) {
    if (object == null) {
      return null;
    }

  if (containsObject(object) && getKey(object) == key) {
      return key;
    }

    COSObjectKey actualKey = key ?? COSObjectKey(++_highestXRefObjectNumber, 0);

    if (containsKey(actualKey)) {
      actualKey = COSObjectKey(++_highestXRefObjectNumber, 0);
    } else {
      _highestXRefObjectNumber =
          actualKey.objectNumber > _highestXRefObjectNumber
              ? actualKey.objectNumber
              : _highestXRefObjectNumber;
    }

    if (object is COSObject) {
      object.key = actualKey;
    } else {
      object.key = actualKey;
      object.isDirect = false;
    }

    _keyPool[actualKey] = object;
    _objectPool[object] = actualKey;
    return actualKey;
  }

  COSObjectKey? getKey(COSBase object) {
    if (object is COSObject) {
      final pooled = _objectPool[object.object];
      if (pooled != null) {
        return pooled;
      }
    }
    return _objectPool[object];
  }

  COSBase? getObject(COSObjectKey key) => _keyPool[key];

  bool containsKey(COSObjectKey key) => _keyPool.containsKey(key);

  bool containsObject(COSBase object) {
    if (object is COSObject) {
      return _objectPool.containsKey(object.object);
    }
    return _objectPool.containsKey(object);
  }

  int get highestXRefObjectNumber => _highestXRefObjectNumber;
}

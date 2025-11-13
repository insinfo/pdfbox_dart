import 'cos_base.dart';
import 'cos_null.dart';
import 'cos_object_key.dart';

class COSObject extends COSBase {
  COSObject(int objectNumber, int generationNumber, [COSBase? object])
      : _key = COSObjectKey(objectNumber, generationNumber) {
    super.key = _key;
    this.object = object;
  }

  COSObject.fromKey(COSObjectKey key, [COSBase? object]) : _key = key {
    super.key = key;
    this.object = object;
  }

  COSObjectKey? _key;

  @override
  COSObjectKey? get key => _key;

  @override
  set key(COSObjectKey? value) {
    _key = value;
    super.key = value;
  }

  COSBase _object = COSNull.instance;

  COSBase get object => _object;

  set object(COSBase? value) {
    _object = value ?? COSNull.instance;
  }

  int get objectNumber => key?.objectNumber ?? 0;

  int get generationNumber => key?.generationNumber ?? 0;

  bool get isNull => _object == COSNull.instance;

  @override
  String toString() => 'COSObject($key -> $_object)';
}

import 'cos_base.dart';
import 'cos_null.dart';
import 'cos_object_key.dart';

class COSObject extends COSBase {
  COSObject(int objectNumber, int generationNumber, [COSBase? object])
      : key = COSObjectKey(objectNumber, generationNumber) {
    this.object = object;
  }

  COSObject.fromKey(this.key, [COSBase? object]) {
    this.object = object;
  }

  final COSObjectKey key;

  COSBase _object = COSNull.instance;

  COSBase get object => _object;

  set object(COSBase? value) {
    _object = value ?? COSNull.instance;
  }

  int get objectNumber => key.objectNumber;

  int get generationNumber => key.generationNumber;

  bool get isNull => _object == COSNull.instance;

  @override
  String toString() => 'COSObject($key -> $_object)';
}

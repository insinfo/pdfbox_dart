import '../../cos/cos_base.dart';
import '../../cos/cos_object_key.dart';
import 'abstract_x_reference.dart';
import 'x_reference_type.dart';

class ObjectStreamXReference extends AbstractXReference {
  ObjectStreamXReference(
    this.objectStreamIndex,
    this.key,
    this.object,
    this.parentKey,
  ) : super(XReferenceType.objectStreamEntry);

  final int objectStreamIndex;
  final COSObjectKey key;
  final COSBase object;
  final COSObjectKey parentKey;

  @override
  COSObjectKey get referencedKey => key;

  COSBase get referencedObject => object;

  COSObjectKey get parentObjectKey => parentKey;

  @override
  int get secondColumnValue => parentKey.objectNumber;

  @override
  int get thirdColumnValue => objectStreamIndex;

  @override
  String toString() =>
      'ObjectStreamEntry{ key=$key, type=${type.numericValue}, objectStreamIndex=$objectStreamIndex, parent=$parentKey }';
}

import '../../cos/cos_object_key.dart';
import 'abstract_x_reference.dart';
import 'x_reference_type.dart';

class FreeXReference extends AbstractXReference {
  FreeXReference(this.key, this.nextFreeObject)
      : super(XReferenceType.free);

  static final FreeXReference nullEntry =
      FreeXReference(const COSObjectKey(0, 65535), 0);

  final COSObjectKey key;
  final int nextFreeObject;

  @override
  COSObjectKey get referencedKey => key;

  @override
  int get secondColumnValue => nextFreeObject;

  @override
  int get thirdColumnValue => key.generationNumber;

  @override
  String toString() =>
      'FreeReference{key=$key, nextFreeObject=$nextFreeObject, type=${type.numericValue}}';
}

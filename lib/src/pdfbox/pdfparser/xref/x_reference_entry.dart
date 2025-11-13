import '../../cos/cos_object_key.dart';
import 'x_reference_type.dart';

abstract class XReferenceEntry implements Comparable<XReferenceEntry> {
  XReferenceType get type;

  COSObjectKey? get referencedKey;

  int get firstColumnValue;

  int get secondColumnValue;

  int get thirdColumnValue;
}

import '../../cos/cos_object_key.dart';
import 'x_reference_entry.dart';
import 'x_reference_type.dart';

abstract class AbstractXReference implements XReferenceEntry {
  AbstractXReference(this.type);

  @override
  final XReferenceType type;

  @override
  int get firstColumnValue => type.numericValue;

  @override
  COSObjectKey? get referencedKey;

  @override
  int compareTo(XReferenceEntry other) {
    final currentKey = referencedKey;
    final otherKey = other.referencedKey;
    if (currentKey == null) {
      return -1;
    }
    if (otherKey == null) {
      return 1;
    }
    final objectComparison = currentKey.objectNumber.compareTo(otherKey.objectNumber);
    if (objectComparison != 0) {
      return objectComparison;
    }
    return currentKey.generationNumber.compareTo(otherKey.generationNumber);
  }
}

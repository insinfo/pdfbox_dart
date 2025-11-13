import '../../cos/cos_base.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_object_key.dart';
import '../../cos/cos_stream.dart';
import 'abstract_x_reference.dart';
import 'x_reference_type.dart';

class NormalXReference extends AbstractXReference {
  NormalXReference(this.byteOffset, this.key, this.object)
      : isObjectStream = _isObjectStream(object),
        super(XReferenceType.normal);

  final int byteOffset;
  final COSObjectKey key;
  final COSBase object;
  final bool isObjectStream;

  static bool _isObjectStream(COSBase object) {
    final base = object is COSObject ? object.object : object;
    if (base is COSStream) {
      final type = base.getCOSName(COSName.type);
      return type == COSName.objStm;
    }
    return false;
  }

  @override
  COSObjectKey get referencedKey => key;

  COSBase get referencedObject => object;

  bool get referencesObjectStream => isObjectStream;

  @override
  int get secondColumnValue => byteOffset;

  @override
  int get thirdColumnValue => key.generationNumber;

  @override
  String toString() {
    final prefix = referencesObjectStream ? 'ObjectStreamParent' : 'NormalReference';
    return '$prefix{ key=$key, type=${type.numericValue}, byteOffset=$byteOffset }';
  }
}

import '../../cos/cos_name.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_stream.dart';
import '../pd_document.dart';
import '../pd_stream.dart';

/// Represents an object stream (/ObjStm) used to store compressed objects.
class PDObjectStream extends PDStream {
  PDObjectStream(COSStream stream) : super(stream);

  /// Creates and registers a new object stream within [document].
  static PDObjectStream createStream(PDDocument document) {
    final cosStream = COSStream();
    document.cosDocument.createObject(cosStream);
    final stream = PDObjectStream(cosStream);
    stream.cosStream[COSName.type] = COSName.objStm;
    return stream;
  }

  /// Returns the stream type, typically `ObjStm`.
  String? get type => cosStream.getNameAsString(COSName.type);

  /// Number of objects stored within this object stream.
  int get numberOfObjects => cosStream.getInt(COSName.n) ?? 0;

  set numberOfObjects(int value) => cosStream.setInt(COSName.n, value);

  /// Byte offset to the first object in the decoded stream.
  int get firstByteOffset => cosStream.getInt(COSName.first) ?? 0;

  set firstByteOffset(int value) => cosStream.setInt(COSName.first, value);

  /// Returns the object stream this stream extends, if any.
  PDObjectStream? get extendsStream {
  final base = cosStream.getDictionaryObject(COSName.extendsName);
    final resolved = base is COSObject ? base.object : base;
    return resolved is COSStream ? PDObjectStream(resolved) : null;
  }

  set extendsStream(PDObjectStream? stream) {
    if (stream == null) {
      cosStream.setItem(COSName.extendsName, null);
    } else {
      cosStream[COSName.extendsName] = stream.cosStream;
    }
  }
}

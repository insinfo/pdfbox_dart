import 'dart:typed_data';

import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../pd_document.dart';
import '../pd_stream.dart';

/// Represents document-level metadata streams.
class PDMetadata extends PDStream {
  PDMetadata(PDDocument document) : super(COSStream()) {
    _initialiseDictionary();
  }

  PDMetadata.fromBytes(PDDocument document, List<int> data)
      : super(COSStream()) {
    _initialiseDictionary();
    importXMPMetadata(data);
  }

  PDMetadata.fromStream(COSStream stream) : super(stream);

  Uint8List? exportXMPMetadata() => encodedBytes;

  void importXMPMetadata(List<int> xmp) {
    encodedBytes = Uint8List.fromList(xmp);
  }

  void _initialiseDictionary() {
    cosStream.setName(COSName.type, 'Metadata');
    cosStream.setName(COSName.subtype, 'XML');
  }
}

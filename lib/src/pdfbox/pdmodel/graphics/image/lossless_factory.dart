import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../cos/cos_name.dart';
import '../../pd_document.dart';
import '../../pd_stream.dart';
import '../pdxobject.dart';

/// Factory for creating lossless image XObjects.
class LosslessFactory {
  /// Create a lossless image XObject from a [Uint8List] containing image data (PNG, etc.).
  static Future<PDImageXObject> createFromBytes(
      PDDocument document, Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Could not decode image');
    }
    return createFromImage(document, image);
  }

  /// Create a lossless image XObject from a [img.Image].
  static PDImageXObject createFromImage(PDDocument document, img.Image image) {
    // Basic implementation: convert to RGB and compress as Flate
    final rgbImage = image.convert(numChannels: 3);
    final pixels = rgbImage.toUint8List();

    final stream = PDStream(document.cosDocument.createCOSStream());
    final cosStream = stream.cosStream;
    cosStream.data = pixels;
    cosStream.addFilter(COSName.flateDecode);

    cosStream.setInt(COSName.width, rgbImage.width);
    cosStream.setInt(COSName.height, rgbImage.height);
    cosStream.setInt(COSName.bitsPerComponent, 8);
    cosStream.setName(COSName.colorSpace, 'DeviceRGB');

    return PDImageXObject(stream);
  }
}

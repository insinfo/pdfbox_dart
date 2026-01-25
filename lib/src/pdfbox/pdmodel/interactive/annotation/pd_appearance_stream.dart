import '../../../cos/cos_stream.dart';
import '../../pd_document.dart';
import '../../graphics/form/pd_form_xobject.dart';

/// An appearance stream is a form XObject, a self-contained content stream that shall be rendered inside the annotation
/// rectangle.
class PDAppearanceStream extends PDFormXObject {
  /// Creates a Form XObject for reading.
  PDAppearanceStream(COSStream stream) : super.fromCOSStream(stream);

  /// Creates a Form Image XObject for writing, in the given document.
  PDAppearanceStream.forDocument(PDDocument document)
      : super.forDocument(document);
}


import '../../../cos/cos_stream.dart';
import '../../pd_document.dart';
import '../../pd_stream.dart';
import '../../resource_cache.dart';
import 'pd_form_xobject.dart';

/// A transparency group.
class PDTransparencyGroup extends PDFormXObject {
  PDTransparencyGroup(PDStream stream) : super(stream);

  PDTransparencyGroup.fromCOSStream(COSStream stream,
      {ResourceCache? cache})
      : super.fromCOSStream(stream) {
    resourceCache = cache;
  }

  PDTransparencyGroup.forDocument(PDDocument document) : super.forDocument(document);
}

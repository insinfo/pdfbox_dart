import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../pd_stream.dart';
import 'pdxobject.dart';

/// Minimal wrapper for PostScript XObjects (Subtype /PS).
class PDPostScriptXObject extends PDXObject {
  PDPostScriptXObject(PDStream stream) : super(stream, COSName.ps);

  PDPostScriptXObject.fromCOSStream(COSStream stream)
      : super.fromCOSStream(stream, COSName.ps);
}

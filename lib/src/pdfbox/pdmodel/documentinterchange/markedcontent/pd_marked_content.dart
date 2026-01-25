import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/cos_objectable.dart';

class PDMarkedContent implements COSObjectable {
  final COSName _tag;
  final COSDictionary? _properties;

  PDMarkedContent(this._tag, this._properties);

  static PDMarkedContent create(COSName tag, COSDictionary? properties) {
    return PDMarkedContent(tag, properties);
  }

  @override
  COSDictionary get cosObject => _properties ?? COSDictionary();

  COSName get tag => _tag;

  COSDictionary? get properties => _properties;

  String? get actualText {
    return _properties?.getString(COSName.actualText);
  }

  String? get mcid {
    return _properties?.getString(COSName.mcid);
  }

  String? get language {
    return _properties?.getString(COSName.lang);
  }

  String? get alternateDescription {
    return _properties?.getString(COSName.alt);
  }

  String? get expandedForm {
    return _properties?.getString(COSName.e);
  }
}


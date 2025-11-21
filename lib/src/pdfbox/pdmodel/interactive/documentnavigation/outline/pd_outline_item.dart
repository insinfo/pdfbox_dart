import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'pd_outline_node.dart';

class PDOutlineItem extends PDOutlineNode {
  PDOutlineItem([COSDictionary? dictionary]) : super(dictionary);

  String? get title => cosObject.getString(COSName.title);

  set title(String? title) {
    cosObject.setString(COSName.title, title);
  }
}

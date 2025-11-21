import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/cos_objectable.dart';

class PDOutlineNode implements COSObjectable {
  final COSDictionary _dictionary;

  PDOutlineNode([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  @override
  COSDictionary get cosObject => _dictionary;
}

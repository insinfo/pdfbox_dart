import 'package:dart_graphics/dart_graphics.dart';

import '../../../../cos/cos_array.dart';
import '../../../../cos/cos_dictionary.dart';
import '../../../../cos/cos_document.dart';
import '../../../../cos/cos_name.dart';
import '../../../pd_document.dart';
import '../../../pd_page.dart';
import '../../../pd_resources.dart';
import '../../../common/pd_rectangle.dart';
import '../../../pd_stream.dart';
import '../../../graphics/form/pd_form_xobject.dart';
import '../../../graphics/pdxobject.dart';
import '../../annotation/pd_annotation_appearance.dart';
import '../../form/pd_acro_form.dart';
import '../../form/pd_signature_field.dart';
import '../../form/pd_field.dart';

/// Structure to hold the components of a visible signature template.
class PDFTemplateStructure {
  PDPage? page;
  PDDocument? template;
  PDAcroForm? acroForm;
  PDSignatureField? signatureField;
  COSDictionary? acroFormDictionary;
  PDRectangle? signatureRectangle;
  COSArray? procSet;
  PDImageXObject? image;
  PDRectangle? formatterRectangle;
  PDStream? holderFormStream;
  PDResources? holderFormResources;
  PDFormXObject? holderForm;
  PDAppearanceDictionary? appearanceDictionary;
  PDStream? innerFormStream;
  PDResources? innerFormResources;
  PDFormXObject? innerForm;
  PDStream? imageFormStream;
  PDResources? imageFormResources;
  PDFormXObject? imageForm;
  COSDocument? visualSignature;
  List<PDField>? fields;
  Affine? affineTransform;
  COSName? imageName;
  COSName? imageFormName;
  COSName? innerFormName;

  PDFTemplateStructure();
}

import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart';

import '../../../../cos/cos_array.dart';
import '../../../../cos/cos_name.dart';
import '../../../pd_document.dart';
import '../../../pd_page.dart';
import '../../../pd_resources.dart';
import '../../../pd_stream.dart';
import '../../../common/pd_rectangle.dart';
import '../../../graphics/form/pd_form_xobject.dart';
import '../../../graphics/pdxobject.dart';
import '../../form/pd_acro_form.dart';
import '../../form/pd_signature_field.dart';
import 'pd_template_structure.dart';
import 'pd_visible_sign_designer.dart';

/// That class builds visible signature template which will be added in our PDF document.
abstract class PDFTemplateBuilder {
  /// In order to create Affine Transform, using parameters.
  void createAffineTransform(Affine affineTransform);

  /// Creates specified size page.
  void createPage(PDVisibleSignDesigner properties);

  /// Creates template using page.
  Future<void> createTemplate(PDPage page);

  /// Creates Acro forms in the template.
  void createAcroForm(PDDocument template);

  /// Creates signature fields.
  Future<void> createSignatureField(PDAcroForm acroForm);

  /// Creates the signature with the given name and assign it to the signature field parameter and assign the page
  /// parameter to the widget.
  Future<void> createSignature(
      PDSignatureField pdSignatureField, PDPage page, String signerName);

  /// Create AcroForm Dictionary.
  Future<void> createAcroFormDictionary(
      PDAcroForm acroForm, PDSignatureField signatureField);

  /// Creates SignatureRectangle.
  Future<void> createSignatureRectangle(
      PDSignatureField signatureField, PDVisibleSignDesigner properties);

  /// Creates procSetArray of PDF,Text,ImageB,ImageC,ImageI.
  void createProcSetArray();

  /// Creates signature image.
  Future<void> createSignatureImage(PDDocument template, Uint8List imageBytes);

  /// An array of four numbers in the form coordinate system, giving the coordinates of the left, bottom, right, and
  /// top edges, respectively, of the form XObject’s bounding box.
  void createFormatterRectangle(List<int> params);

  /// Create a holder for the form stream.
  void createHolderFormStream(PDDocument template);

  /// Creates resources of form
  void createHolderFormResources();

  /// Creates Form
  void createHolderForm(
      PDResources holderFormResources, PDStream holderFormStream, PDRectangle bbox);

  /// Creates appearance dictionary
  Future<void> createAppearanceDictionary(
      PDFormXObject holderForm, PDSignatureField signatureField);

  /// Create a holder for the inner form stream.
  void createInnerFormStream(PDDocument template);

  /// Creates InnerForm
  void createInnerFormResource();

  /// Creates InnerForm.
  void createInnerForm(
      PDResources innerFormResources, PDStream innerFormStream, PDRectangle bbox);

  /// Insert given from as inner form.
  void insertInnerFormToHolderResources(
      PDFormXObject innerForm, PDResources holderFormResources);

  /// Create image form stream.
  void createImageFormStream(PDDocument template);

  /// Create resource of image form
  void createImageFormResources();

  /// Creates Image form
  Future<void> createImageForm(
      PDResources imageFormResources,
      PDResources innerFormResource,
      PDStream imageFormStream,
      PDRectangle bbox,
      Affine affineTransform,
      PDImageXObject img);

  /// Creates the background layer form (n0).
  Future<void> createBackgroundLayerForm(
      PDResources innerFormResource, PDRectangle bbox);

  /// Inject procSetArray
  void injectProcSetArray(
      PDFormXObject innerForm,
      PDPage page,
      PDResources innerFormResources,
      PDResources imageFormResources,
      PDResources holderFormResources,
      COSArray procSet);

  /// injects appearance streams
  Future<void> injectAppearanceStreams(
      PDStream holderFormStream,
      PDStream innerFormStream,
      PDStream imageFormStream,
      COSName imageFormName,
      COSName imageName,
      COSName innerFormName,
      PDVisibleSignDesigner properties);

  /// just to create visible signature
  void createVisualSignature(PDDocument template);

  /// adds Widget Dictionary
  Future<void> createWidgetDictionary(
      PDSignatureField signatureField, PDResources holderFormResources);

  /// Returns the PDF template Structure
  PDFTemplateStructure getStructure();

  /// Closes template
  Future<void> closeTemplate(PDDocument template);
}

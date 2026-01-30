import 'dart:typed_data';
import 'package:dart_graphics/dart_graphics.dart';

import '../../../../cos/cos_array.dart';
import '../../../../cos/cos_dictionary.dart';
import '../../../../cos/cos_name.dart';
import '../../../pd_document.dart';
import '../../../pd_page.dart';
import '../../../pd_resources.dart';
import '../../../pd_stream.dart';
import '../../../common/pd_rectangle.dart';
import '../../../graphics/form/pd_form_xobject.dart';
import '../../../graphics/pdxobject.dart';
import '../../annotation/pd_annotation_appearance.dart';
import '../../annotation/pd_appearance_stream.dart';
import '../pd_signature.dart';
import '../../form/pd_acro_form.dart';
import '../../form/pd_signature_field.dart';
import 'pd_template_structure.dart';
import 'pd_visible_sign_designer.dart';
import 'pdf_template_builder.dart';
import '../../../graphics/image/lossless_factory.dart';

/// Implementation of [PDFTemplateBuilder].
class PDVisibleSigBuilder implements PDFTemplateBuilder {
  final PDFTemplateStructure _structure = PDFTemplateStructure();

  @override
  PDFTemplateStructure getStructure() => _structure;

  @override
  void createProcSetArray() {
    final procSet = COSArray();
    procSet.add(COSName('PDF'));
    procSet.add(COSName('Text'));
    procSet.add(COSName('ImageB'));
    procSet.add(COSName('ImageC'));
    procSet.add(COSName('ImageI'));
    _structure.procSet = procSet;
  }

  @override
  void createPage(PDVisibleSignDesigner properties) {
    final page = PDPage();
    page.mediaBox = PDRectangle(0, 0, properties.pageWidth, properties.pageHeight);
    _structure.page = page;
  }

  @override
  Future<void> createTemplate(PDPage page) async {
    final template = PDDocument();
    template.addPage(page);
    _structure.template = template;
  }

  @override
  void createAcroForm(PDDocument template) {
    final acroForm = PDAcroForm(template.cosDocument, template.resourceCache);
    template.documentCatalog.acroForm = acroForm;
    _structure.acroForm = acroForm;
  }

  @override
  Future<void> createSignatureField(PDAcroForm acroForm) async {
    final sf = PDSignatureField(acroForm, COSDictionary(), null);
    _structure.signatureField = sf;
  }

  @override
  Future<void> createSignature(PDSignatureField pdSignatureField, PDPage page, String name) async {
    final sig = PDSignature();
    pdSignatureField.signature = sig;
    _structure.visualSignature = _structure.template!.cosDocument; 
  }

  @override
  Future<void> createAcroFormDictionary(PDAcroForm acroForm, PDSignatureField signatureField) async {
    _structure.acroFormDictionary = acroForm.cosObject;
  }

  @override
  void createAffineTransform(Affine transform) {
    _structure.affineTransform = transform;
  }

  @override
  Future<void> createSignatureRectangle(PDSignatureField signatureField, PDVisibleSignDesigner properties) async {
    final rect = PDRectangle(
      properties.xAxisValue,
      properties.yAxisValue,
      properties.widthValue + properties.xAxisValue,
      properties.heightValue + properties.yAxisValue,
    );
    _structure.signatureRectangle = rect;
    
    final widget = signatureField.getWidgets()[0];
    widget.rect = [rect.lowerLeftX, rect.lowerLeftY, rect.upperRightX, rect.upperRightY];
  }

  @override
  void createFormatterRectangle(List<int> params) {
    _structure.formatterRectangle = PDRectangle(
      params[0].toDouble(),
      params[1].toDouble(),
      params[2].toDouble(),
      params[3].toDouble(),
    );
  }

  @override
  Future<void> createSignatureImage(PDDocument template, Uint8List imageBytes) async {
    final image = await LosslessFactory.createFromBytes(template, imageBytes);
    _structure.image = image;
  }

  @override
  void createHolderFormStream(PDDocument template) {
    _structure.holderFormStream = PDStream(template.cosDocument.createCOSStream());
  }

  @override
  void createHolderFormResources() {
    _structure.holderFormResources = PDResources();
  }

  @override
  void createHolderForm(PDResources resources, PDStream stream, PDRectangle bbox) {
    final form = PDFormXObject(stream);
    form.resources = resources;
    form.boundingBox = bbox;
    form.formType = 1;
    _structure.holderForm = form;
  }

  @override
  Future<void> createAppearanceDictionary(PDFormXObject holderForm, PDSignatureField signatureField) async {
    final appearance = PDAppearanceDictionary();
    appearance.setNormalAppearanceStream(PDAppearanceStream(holderForm.cosObject));
    signatureField.getWidgets()[0].appearance = appearance;
    _structure.appearanceDictionary = appearance;
  }

  @override
  void createInnerFormStream(PDDocument template) {
    _structure.innerFormStream = PDStream(template.cosDocument.createCOSStream());
  }

  @override
  void createInnerFormResource() {
    _structure.innerFormResources = PDResources();
  }

  @override
  void createInnerForm(PDResources resources, PDStream stream, PDRectangle bbox) {
    final form = PDFormXObject(stream);
    form.resources = resources;
    form.boundingBox = bbox;
    form.formType = 1;
    _structure.innerForm = form;
    _structure.innerFormName = COSName('FRM');
  }

  @override
  void insertInnerFormToHolderResources(PDFormXObject innerForm, PDResources holderResources) {
    holderResources.addXObject(_structure.innerFormName!, innerForm);
  }

  @override
  void createImageFormStream(PDDocument template) {
    _structure.imageFormStream = PDStream(template.cosDocument.createCOSStream());
  }

  @override
  void createImageFormResources() {
    _structure.imageFormResources = PDResources();
  }

  @override
  Future<void> createImageForm(PDResources imageFormResources, PDResources innerFormResource, PDStream imageFormStream, PDRectangle bbox, Affine affineTransform, PDImageXObject image) async {
    final form = PDFormXObject(imageFormStream);
    form.resources = imageFormResources;
    form.boundingBox = bbox;
    form.formType = 1;
    
    _structure.imageForm = form;
    _structure.imageFormName = COSName('n2');
    _structure.imageName = COSName('img');
    
    innerFormResource.addXObject(_structure.imageFormName!, form);
    imageFormResources.addXObject(_structure.imageName!, image);
  }

  @override
  Future<void> createBackgroundLayerForm(PDResources innerFormResource, PDRectangle bbox) async {
    final stream = PDStream(_structure.template!.cosDocument.createCOSStream());
    final form = PDFormXObject(stream);
    form.resources = PDResources();
    form.boundingBox = bbox;
    form.formType = 1;
    innerFormResource.addXObject(COSName('n0'), form);
  }

  @override
  void injectProcSetArray(PDFormXObject innerForm, PDPage page, PDResources innerFormResources, PDResources imageFormResources, PDResources holderFormResources, COSArray procSet) {
    innerFormResources.cosObject.setItem(COSName.procSet, procSet);
    imageFormResources.cosObject.setItem(COSName.procSet, procSet);
    holderFormResources.cosObject.setItem(COSName.procSet, procSet);
  }

  @override
  Future<void> injectAppearanceStreams(PDStream holderFormStream, PDStream innerFormStream, PDStream imageFormStream, COSName imageFormName, COSName imageName, COSName innerFormName, PDVisibleSignDesigner properties) async {
    // Holder form stream: /FRM Do
    final hOut = holderFormStream.cosStream.createUnfilteredOutputStream();
    hOut.write(Uint8List.fromList('/$innerFormName Do'.codeUnits));
    hOut.close();

    // Inner form stream: /n0 Do /n2 Do
    final iOut = innerFormStream.cosStream.createUnfilteredOutputStream();
    iOut.write(Uint8List.fromList('/n0 Do\n/n2 Do'.codeUnits));
    iOut.close();

    // Image form stream: q ... /img Do Q
    final imgOut = imageFormStream.cosStream.createUnfilteredOutputStream();
    final transform = properties.transform;
    final matrix = '${transform.sx} ${transform.shy} ${transform.shx} ${transform.sy} ${transform.tx} ${transform.ty}';
    imgOut.write(Uint8List.fromList('q $matrix cm /$imageName Do Q'.codeUnits));
    imgOut.close();
  }

  @override
  void createVisualSignature(PDDocument template) {
    _structure.visualSignature = template.cosDocument;
  }

  @override
  Future<void> createWidgetDictionary(PDSignatureField signatureField, PDResources holderFormResources) async {
    final widget = signatureField.getWidgets()[0];
    widget.cosObject.setItem(COSName.dr, holderFormResources.cosObject);
  }

  @override
  Future<void> closeTemplate(PDDocument template) async {
    template.close();
  }
}

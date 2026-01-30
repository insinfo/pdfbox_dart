import 'dart:typed_data';

import '../../../../cos/cos_document.dart';
import '../../../pd_document.dart';
import 'pdf_template_builder.dart';
import 'pd_template_structure.dart';
import 'pd_visible_sign_designer.dart';

/// Class to build PDF template for visible signatures.
class PDFTemplateCreator {
  final PDFTemplateBuilder _pdfBuilder;

  PDFTemplateCreator(this._pdfBuilder);

  /// Returns the PDFTemplateStructure object.
  PDFTemplateStructure get pdfStructure => _pdfBuilder.getStructure();

  /// Build a PDF with a visible signature step by step, and return it as bytes.
  Future<Uint8List> buildPDF(PDVisibleSignDesigner properties) async {
    final pdfStructure = _pdfBuilder.getStructure();

    _pdfBuilder.createProcSetArray();

    _pdfBuilder.createPage(properties);
    final page = pdfStructure.page!;

    await _pdfBuilder.createTemplate(page);

    final template = pdfStructure.template!;
    try {
      _pdfBuilder.createAcroForm(template);
      final acroForm = pdfStructure.acroForm!;
      
      await _pdfBuilder.createSignatureField(acroForm);
      final pdSignatureField = pdfStructure.signatureField!;
      
      await _pdfBuilder.createSignature(pdSignatureField, page, "");
      
      await _pdfBuilder.createAcroFormDictionary(acroForm, pdSignatureField);
      
      _pdfBuilder.createAffineTransform(properties.transform);
      final transform = pdfStructure.affineTransform!;
      
      await _pdfBuilder.createSignatureRectangle(pdSignatureField, properties);
      _pdfBuilder.createFormatterRectangle(properties.formatterRectangleParameters);
      final bbox = pdfStructure.formatterRectangle!;
      
      if (properties.imageBytes != null) {
        await _pdfBuilder.createSignatureImage(template, properties.imageBytes!);
      }
      
      _pdfBuilder.createHolderFormStream(template);
      final holderFormStream = pdfStructure.holderFormStream!;
      _pdfBuilder.createHolderFormResources();
      final holderFormResources = pdfStructure.holderFormResources!;
      _pdfBuilder.createHolderForm(holderFormResources, holderFormStream, bbox);
      
      await _pdfBuilder.createAppearanceDictionary(pdfStructure.holderForm!, pdSignatureField);
      
      _pdfBuilder.createInnerFormStream(template);
      _pdfBuilder.createInnerFormResource();
      final innerFormResource = pdfStructure.innerFormResources!;
      _pdfBuilder.createInnerForm(innerFormResource, pdfStructure.innerFormStream!, bbox);
      final innerForm = pdfStructure.innerForm!;
      
      _pdfBuilder.insertInnerFormToHolderResources(innerForm, holderFormResources);
      
      _pdfBuilder.createImageFormStream(template);
      final imageFormStream = pdfStructure.imageFormStream!;
      _pdfBuilder.createImageFormResources();
      final imageFormResources = pdfStructure.imageFormResources!;
      
      if (pdfStructure.image != null) {
        await _pdfBuilder.createImageForm(imageFormResources, innerFormResource,
            imageFormStream, bbox, transform, pdfStructure.image!);
      }
      
      await _pdfBuilder.createBackgroundLayerForm(innerFormResource, bbox);
      
      _pdfBuilder.injectProcSetArray(innerForm, page, innerFormResource,
          imageFormResources, holderFormResources, pdfStructure.procSet!);
      
      final imageFormName = pdfStructure.imageFormName!;
      final imageName = pdfStructure.imageName!;
      final innerFormName = pdfStructure.innerFormName!;
      
      await _pdfBuilder.injectAppearanceStreams(holderFormStream, pdfStructure.innerFormStream!,
          imageFormStream, imageFormName, imageName, innerFormName, properties);
      
      _pdfBuilder.createVisualSignature(template);
      await _pdfBuilder.createWidgetDictionary(pdSignatureField, holderFormResources);
      
      return await _getVisualSignatureAsBytes(pdfStructure.visualSignature!);
    } finally {
      // Template cleanup
    }
  }

  Future<Uint8List> _getVisualSignatureAsBytes(COSDocument visualSignature) async {
    final tempDoc = PDDocument.fromCOSDocument(visualSignature);
    try {
      return await tempDoc.saveToBytes();
    } finally {
      // tempDoc.close();
    }
  }
}

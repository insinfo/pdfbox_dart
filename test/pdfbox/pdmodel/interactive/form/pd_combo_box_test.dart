import 'dart:convert';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_combo_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type1_font.dart';
import 'package:test/test.dart';

void main() {
  group('PDComboBox', () {
    test('setValue generates appearance stream', () {
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);
      
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      doc.documentCatalog.acroForm = acroForm;
      
      // Add default font to AcroForm default resources
      final resources = PDResources(COSDictionary());
      resources.setFont(COSName.getPDFName('Helv'), PDType1Font.helvetica().cosObject);
      acroForm.defaultResources = resources;
      
      final dict = COSDictionary();
      dict.setName(COSName.subtype, 'Widget');
      dict.setName(COSName.type, 'Annot');
      
      final rectArray = COSArray()
        ..add(COSFloat(10))
        ..add(COSFloat(10))
        ..add(COSFloat(100))
        ..add(COSFloat(30));
      dict.setItem(COSName.rect, rectArray);
      
      final field = PDComboBox(acroForm, dict, null);
      field.setOptions(['Option 1', 'Option 2', 'Option 3']);
      
      // Set default appearance string
      field.setDefaultAppearance('/Helv 12 Tf 0 g');
      
      field.setValue('Option 2');
      
      final widgets = field.getWidgets();
      expect(widgets.length, 1);
      
      final widget = widgets[0];
      final appearance = widget.appearance;
      expect(appearance, isNotNull);
      
      final normal = appearance!.normalAppearance;
      expect(normal, isNotNull);
      expect(normal!.isStream, isTrue);
      
      final stream = normal.appearanceStream;
      final content = utf8.decode(stream.cosObject.data ?? []);
      
      // Verify content stream contains the text
      expect(content, contains('(Option 2) Tj'));
      expect(content, contains('/Helv 12 Tf'));
    });
  });
}


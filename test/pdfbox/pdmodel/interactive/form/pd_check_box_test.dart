import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_check_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:test/test.dart';

void main() {
  group('PDCheckBox', () {
    test('setValue updates appearance state', () {
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);
      
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      doc.documentCatalog.acroForm = acroForm;
      
      final dict = COSDictionary();
      dict.setName(COSName.subtype, 'Widget');
      dict.setName(COSName.type, 'Annot');
      
      final rectArray = COSArray()
        ..add(COSFloat(10))
        ..add(COSFloat(10))
        ..add(COSFloat(20))
        ..add(COSFloat(20));
      dict.setItem(COSName.rect, rectArray);
      
      final field = PDCheckBox(acroForm, dict, null);
      
      // Setup basic appearance dictionary with Yes/Off states
      final apDict = COSDictionary();
      final normalAp = COSDictionary();
      normalAp.setItem(COSName.getPDFName('Yes'), COSStream());
      normalAp.setItem(COSName.getPDFName('Off'), COSStream());
      apDict.setItem(COSName.n, normalAp);
      dict.setItem(COSName.appearance, apDict);
      
      field.setValue('Yes');
      
      final widgets = field.getWidgets();
      expect(widgets.length, 1);
      expect(widgets[0].appearanceState, 'Yes');
      
      field.unCheck();
      expect(widgets[0].appearanceState, 'Off');
    });
  });
}


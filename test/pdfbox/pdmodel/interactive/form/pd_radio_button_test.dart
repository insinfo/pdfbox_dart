import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_radio_button.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:test/test.dart';

void main() {
  group('PDRadioButton', () {
    test('setValue updates appearance state for radio group', () {
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);
      
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      doc.documentCatalog.acroForm = acroForm;
      
      final dict = COSDictionary();
      dict.setName(COSName.subtype, 'Widget');
      dict.setName(COSName.type, 'Annot');
      
      final field = PDRadioButton(acroForm, dict, null);
      
      // Create two widgets
      final widget1Dict = COSDictionary();
      widget1Dict.setName(COSName.subtype, 'Widget');
      final widget2Dict = COSDictionary();
      widget2Dict.setName(COSName.subtype, 'Widget');
      
      // Setup appearances
      // Widget 1: Choice1 / Off
      final apDict1 = COSDictionary();
      final normalAp1 = COSDictionary();
      normalAp1.setItem(COSName.getPDFName('Choice1'), COSStream());
      normalAp1.setItem(COSName.getPDFName('Off'), COSStream());
      apDict1.setItem(COSName.n, normalAp1);
      widget1Dict.setItem(COSName.appearance, apDict1);
      
      // Widget 2: Choice2 / Off
      final apDict2 = COSDictionary();
      final normalAp2 = COSDictionary();
      normalAp2.setItem(COSName.getPDFName('Choice2'), COSStream());
      normalAp2.setItem(COSName.getPDFName('Off'), COSStream());
      apDict2.setItem(COSName.n, normalAp2);
      widget2Dict.setItem(COSName.appearance, apDict2);
      
      // Add widgets to field (using Kids)
      final kids = COSArray();
      kids.add(widget1Dict);
      kids.add(widget2Dict);
      dict.setItem(COSName.kids, kids);
      
      // We need to ensure getWidgets returns these kids.
      // PDTerminalField.getWidgets checks if the dictionary itself is a widget or has kids.
      // Since we added Kids, it should return them.
      // However, we also set Subtype=Widget on the field dict, which might make it think it's a single widget.
      // Usually RadioButton field is NOT a widget itself if it has kids.
      dict.removeItem(COSName.subtype); 
      
      // Also need to link Parent in widgets to field?
      // PDTerminalField.getWidgets implementation:
      // if (getCOSObject().containsKey(COSName.KIDS)) { ... }
      
      // Let's verify widgets are retrieved
      final widgets = field.getWidgets();
      expect(widgets.length, 2);
      
      // Set value to Choice1
      field.setValue('Choice1');
      expect(widgets[0].appearanceState, 'Choice1');
      expect(widgets[1].appearanceState, 'Off');
      
      // Set value to Choice2
      field.setValue('Choice2');
      expect(widgets[0].appearanceState, 'Off');
      expect(widgets[1].appearanceState, 'Choice2');
      
      // Set value to Off
      field.setValue('Off');
      expect(widgets[0].appearanceState, 'Off');
      expect(widgets[1].appearanceState, 'Off');
    });
  });
}


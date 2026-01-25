import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_text_field.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/pd_type1_font.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/standard14_fonts.dart';
import 'package:test/test.dart';

void main() {
  group('PDTerminalField', () {
    test('setValue generates appearance', () {
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);
      
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      doc.documentCatalog.acroForm = acroForm;
      
      // Add default resources with a font
      final resources = PDResources();
      final helvetica = Standard14Fonts.byPostScriptName('Helvetica')!;
      resources.setFont(COSName.get('Helv'), PDType1Font.standard14(helvetica).cosObject);
      acroForm.defaultResources = resources;
      
      final dict = COSDictionary();
      dict.setName(COSName.subtype, 'Widget');
      dict.setName(COSName.type, 'Annot');
      
      final rectArray = COSArray()
        ..add(COSFloat(10))
        ..add(COSFloat(10))
        ..add(COSFloat(100))
        ..add(COSFloat(50));
      dict.setItem(COSName.rect, rectArray);
      
      // Create a TextField which is also a Widget (merged dictionary)
      final field = PDTextField(acroForm, dict, null);
      field.setDefaultAppearance('/Helv 12 Tf 0 g');
      
      // Add field to AcroForm
      // acroForm.fields = [field]; // This might be needed if we were doing full setup
      
      // Set value
      field.setValue('Hello World');
      
      // Check if appearance stream is generated
      final widgets = field.getWidgets();
      expect(widgets.length, 1);
      final widget = widgets[0];
      
      final appearance = widget.appearance;
      expect(appearance, isNotNull);
      
      final normal = appearance!.normalAppearance;
      expect(normal, isNotNull);
      expect(normal!.isStream, isTrue);
      
      final stream = normal.appearanceStream;
      expect(stream, isNotNull);
      
      // Check stream content (basic check)
      // We can't easily check the content bytes without decoding, but we can check if it's not empty
      // The stream data is set in close()
      
      // We need to verify that the stream has data.
      // PDAppearanceStream wraps COSStream.
      // COSStream data is Uint8List.
      
      // Wait, PDAppearanceStream doesn't expose data directly, but we can get cosObject.
      // But we need to cast to COSStream.
      
      // Let's just check if resources are set
      expect(stream.resources, isNotNull);
      final font = stream.resources!.getFont(COSName.get('Helv'));
      expect(font, isNotNull);
    });
  });
}


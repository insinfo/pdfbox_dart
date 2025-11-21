import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_text_field.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

void main() {
  group('PDAcroForm', () {
    test('create and retrieve AcroForm', () {
      final doc = PDDocument();
      final catalog = doc.documentCatalog;
      
      expect(catalog.acroForm, isNull);
      
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      catalog.acroForm = acroForm;
      
      expect(catalog.acroForm, isNotNull);
      expect(catalog.acroForm!.cosObject, equals(acroForm.cosObject));
    });

    test('add and retrieve fields', () {
      final doc = PDDocument();
      final catalog = doc.documentCatalog;
      final acroForm = PDAcroForm(doc.cosDocument, doc.resourceCache);
      catalog.acroForm = acroForm;

      final fieldDict = COSDictionary();
      fieldDict.setName(COSName.ft, 'Tx');
      fieldDict.setString(COSName.t, 'MyField');
      fieldDict.setString(COSName.v, 'MyValue');

      final fieldsArray = COSArray();
      fieldsArray.add(fieldDict);
      acroForm.cosObject[COSName.fields] = fieldsArray;

      final fields = acroForm.fields;
      expect(fields.length, 1);
      expect(fields[0], isA<PDTextField>());
      
      final textField = fields[0] as PDTextField;
      expect(textField.partialName, 'MyField');
      expect(textField.value, 'MyValue');
      
      textField.setValue('NewValue');
      expect(textField.value, 'NewValue');
      expect(fieldDict.getString(COSName.v), 'NewValue');
    });
  });
}

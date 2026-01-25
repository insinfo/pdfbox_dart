import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_acro_form.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_check_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_combo_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_field_factory.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_list_box.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_push_button.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_radio_button.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_signature_field.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

void main() {
  group('PDFieldFactory Tests', () {
    late PDDocument document;
    late PDAcroForm acroForm;

    setUp(() {
      document = PDDocument();
      acroForm = PDAcroForm(document.cosDocument, document.resourceCache);
    });

    tearDown(() {
      // document.close();
    });

    test('Create Signature Field', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Sig');
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDSignatureField>());
    });

    test('Create CheckBox', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Btn');
      // No flags, defaults to CheckBox
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDCheckBox>());
    });

    test('Create RadioButton', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Btn');
      dict.setInt(COSName.ff, 1 << 15); // Radio flag
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDRadioButton>());
    });

    test('Create PushButton', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Btn');
      dict.setInt(COSName.ff, 1 << 16); // PushButton flag
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDPushButton>());
    });

    test('Create ComboBox', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Ch');
      dict.setInt(COSName.ff, 1 << 17); // Combo flag
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDComboBox>());
    });

    test('Create ListBox', () {
      final dict = COSDictionary();
      dict.setName(COSName.ft, 'Ch');
      // No Combo flag, defaults to ListBox
      
      final field = PDFieldFactory.createField(acroForm, dict, null);
      expect(field, isA<PDListBox>());
    });
  });
}


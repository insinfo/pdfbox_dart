import 'dart:io';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/form/pd_signature_field.dart';

void main() {
  final file = File('test/assets/2 ass leonardo e mauricio.pdf');
  final bytes = file.readAsBytesSync();
  final doc = PDDocument.loadFromBytes(bytes);
  final acroForm = doc.documentCatalog.acroForm;

  if (acroForm == null) {
    print('No AcroForm found');
    return;
  }

  print('AcroForm found');
  final fields = acroForm.fields;
  print('Top level fields: ${fields.length}');

  int count = 0;
  for (final field in acroForm.fieldTree) {
    count++;
    print('Field: ${field.fullyQualifiedName}');
    final ft = field.cosObject.getNameAsString(COSName.ft);
    print('  FT: $ft');
    if (field is PDSignatureField) {
      print('  Type: PDSignatureField');
      final sig = field.signature;
      print('  Has V: ${sig != null}');
    } else {
      print('  Type: ${field.runtimeType}');
    }
  }
  print('Total fields found via fieldTree: $count');
}

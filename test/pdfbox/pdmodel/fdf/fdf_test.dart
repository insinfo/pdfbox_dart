import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_catalog.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_file_specification.dart';
import 'package:test/test.dart';

void main() {
  group('FDF Classes', () {
    test('FDFDocument creation', () {
      final doc = FDFDocument.create();
      expect(doc.isClosed, isFalse);
      expect(doc.catalog, isNotNull);
      expect(doc.cosDocument, isNotNull);
      expect(doc.cosDocument.headerVersion, equals('1.2'));
      doc.close();
      expect(doc.isClosed, isTrue);
    });

    test('FDFCatalog version', () {
      final catalog = FDFCatalog();
      expect(catalog.version, isNull);
      
      catalog.version = '1.4';
      expect(catalog.version, equals('1.4'));
      
      catalog.version = null;
      expect(catalog.version, isNull);
    });

    test('FDFCatalog fdf dictionary', () {
      final catalog = FDFCatalog();
      final fdf = catalog.fdf;
      expect(fdf, isNotNull);
      expect(fdf, isA<FDFDictionary>());
    });

    test('FDFCatalog signature', () {
      final catalog = FDFCatalog();
      expect(catalog.signature, isNull);
      
      // Note: We can't fully test PDSignature without creating one,
      // but we can verify the getter/setter work
    });

    test('FDFDictionary encoding', () {
      final fdfDict = FDFDictionary();
      
      // Default encoding
      expect(fdfDict.encoding, equals('PDFDocEncoding'));
      
      // Set custom encoding
      fdfDict.encoding = 'UTF-8';
      expect(fdfDict.encoding, equals('UTF-8'));
      
      // Remove encoding (should return default)
      fdfDict.encoding = null;
      expect(fdfDict.encoding, equals('PDFDocEncoding'));
    });

    test('FDFDictionary status', () {
      final fdfDict = FDFDictionary();
      expect(fdfDict.status, isNull);
      
      fdfDict.status = 'Success';
      expect(fdfDict.status, equals('Success'));
      
      fdfDict.status = null;
      expect(fdfDict.status, isNull);
    });

    test('FDFDictionary target', () {
      final fdfDict = FDFDictionary();
      expect(fdfDict.target, isNull);
      
      fdfDict.target = '_blank';
      expect(fdfDict.target, equals('_blank'));
      
      fdfDict.target = null;
      expect(fdfDict.target, isNull);
    });

    test('FDFDictionary ID', () {
      final fdfDict = FDFDictionary();
      expect(fdfDict.id, isNull);
      
      final idArray = COSArray();
      idArray.add(COSString('original-id'));
      idArray.add(COSString('modified-id'));
      fdfDict.id = idArray;
      
      final retrieved = fdfDict.id;
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(2));
    });

    test('FDFDictionary file specification', () {
      final fdfDict = FDFDictionary();
      expect(fdfDict.getFile(), isNull);
      
      // Create a simple file specification
      final fileSpec = PDSimpleFileSpecification(COSString('test.pdf'));
      fdfDict.setFile(fileSpec);
      
      final retrieved = fdfDict.getFile();
      expect(retrieved, isNotNull);
      expect(retrieved!.file, equals('test.pdf'));
    });

    test('FDFDictionary differences', () {
      final fdfDict = FDFDictionary();
      expect(fdfDict.differences, isNull);
      
      // Note: We can't easily test COSStream setting without more setup
    });

    test('Integration: FDFDocument with catalog and dictionary', () {
      final doc = FDFDocument.create();
      final catalog = doc.catalog;
      
      catalog.version = '1.5';
      expect(catalog.version, equals('1.5'));
      
      final fdfDict = catalog.fdf;
      fdfDict.encoding = 'UTF-16';
      fdfDict.status = 'Test status';
      
      expect(catalog.fdf.encoding, equals('UTF-16'));
      expect(catalog.fdf.status, equals('Test status'));
      
      doc.close();
    });
  });
}

import 'dart:io';

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/layer_utility.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/util/matrix.dart';
import 'package:pdfbox_dart/src/io/random_access_write_file.dart';

void main() {
  group('LayerUtility', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pdf_layer_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('import page as form and append as layer', () {
      final doc = PDDocument();
      final page = PDPage()..mediaBox = PDRectangle.a4;
      doc.addPage(page);
      
      final sourceDoc = PDDocument();
      final sourcePage = PDPage()..mediaBox = PDRectangle.a4;
      sourceDoc.addPage(sourcePage);
      
      final layerUtility = LayerUtility(doc);
      final form = layerUtility.importPageAsForm(sourceDoc, sourcePage);
      
      final layer = layerUtility.appendFormAsLayer(page, form, Matrix(), 'MyLayer');
      
      expect(layer.name, 'MyLayer');
      expect(doc.documentCatalog.optionalContentProperties, isNotNull);
      expect(doc.documentCatalog.optionalContentProperties!.hasGroup('MyLayer'), isTrue);
      
      final file = File('${tempDir.path}/layered.pdf');
      final output = RandomAccessWriteFile(file.path);
      doc.save(output);
      output.close();
      
      doc.close();
      sourceDoc.close();
    });
  });
}


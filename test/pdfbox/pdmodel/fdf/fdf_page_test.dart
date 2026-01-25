
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_page_info.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_template.dart';
import 'package:test/test.dart';

void main() {
  group('FDFPage', () {
    test('FDFPage creation and defaults', () {
      FDFPage page = FDFPage();
      expect(page.cosObject, isA<COSDictionary>());
      expect(page.getTemplates(), isNull);
      expect(page.getPageInfo(), isNull);
    });

    test('FDFPage creation from dictionary', () {
      COSDictionary dict = COSDictionary();
      FDFPage page = FDFPage(dict);
      expect(page.cosObject, equals(dict));
    });

    test('FDFPage templates', () {
      FDFPage page = FDFPage();
      
      var template = FDFTemplate();
      // Assuming FDFTemplate has some properties we can set, or just use it as is
      
      List<FDFTemplate> templates = [template];
      page.setTemplates(templates);
      
      expect(page.getTemplates(), isNotNull);
      expect(page.getTemplates()!.length, equals(1));
      // Object equality might not work for FDFTemplate unless it overrides == or we check inner dictionary
      expect(page.getTemplates()![0].cosObject, equals(template.cosObject));
    });

    test('FDFPage page info', () {
      FDFPage page = FDFPage();
      var info = FDFPageInfo();
      
      page.setPageInfo(info);
      
      expect(page.getPageInfo(), isNotNull);
      expect(page.getPageInfo()!.cosObject, equals(info.cosObject));
    });
  });
}


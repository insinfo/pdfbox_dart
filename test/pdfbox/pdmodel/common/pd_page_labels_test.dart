import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_label_range.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_labels.dart';
import 'package:test/test.dart';

void main() {
  test('computes labels for multiple ranges', () {
    final document = PDDocument();
    for (var i = 0; i < 5; i++) {
      document.addPage(PDPage());
    }
    addTearDown(document.close);

    final labels = PDPageLabels(document);

    final introRange = PDPageLabelRange()
      ..style = PDPageLabelRange.styleRomanLower
      ..start = 1
      ..prefix = 'Intro ';
    labels.setLabelItem(0, introRange);

    final sectionRange = PDPageLabelRange()
      ..style = PDPageLabelRange.styleDecimal
      ..start = 1
      ..prefix = 'Sec ';
    labels.setLabelItem(2, sectionRange);

    final pageLabels = labels.getLabelsByPageIndices();
    expect(pageLabels, <String?>[
      'Intro i',
      'Intro ii',
      'Sec 1',
      'Sec 2',
      'Sec 3',
    ]);

    final indices = labels.getPageIndicesByLabels();
    expect(indices['Intro ii'], 1);
    expect(indices['Sec 3'], 4);
  });
}

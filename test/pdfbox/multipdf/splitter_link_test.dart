import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_go_to.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_link.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/splitter.dart';

void main() {
  test('Splitter removes link destinations to pages outside split result', () {
    final doc = PDDocument();
    try {
      final page1 = PDPage();
      final page2 = PDPage();
      doc.addPage(page1);
      doc.addPage(page2);

      final destArray = COSArray()
        ..addObject(page2.cosObject)
        ..addName('Fit');
      final destination = PDPageDestination.fromArray(destArray)!;

      final action = PDActionGoTo();
      action.destination = destination;

      final link = PDAnnotationLink();
      link.action = action;
      page1.annotations = [link];

      final splitter = Splitter();
      splitter.setSplitAtPage(1);
      final docs = splitter.split(doc);
      try {
        expect(docs.length, equals(2));

        final first = docs[0];
        final annotations = first.getPage(0).annotations;
        expect(annotations.length, equals(1));
        final cloned = annotations.first as PDAnnotationLink;
        final clonedAction = cloned.action as PDActionGoTo?;
        expect(clonedAction, isNotNull);
        final clonedDest = clonedAction!.destination as PDPageDestination?;
        expect(clonedDest, isNotNull);
        expect(clonedDest!.page, isA<COSName>());
      } finally {
        for (final splitDoc in docs) {
          splitDoc.close();
        }
      }
    } finally {
      doc.close();
    }
  });
}

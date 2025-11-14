import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page_content_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:test/test.dart';

void main() {
  group('PDPageContentStream', () {
    test('overwrites content with basic text operations', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final fontResource = COSName.get('F1');
      final stream = PDPageContentStream(document, page);
      stream.resources.registerStandard14Font(fontResource, 'Helvetica');

      stream.beginText();
      stream.setFont(fontResource, 12);
      stream.newLineAtOffset(72, 700);
      stream.showText('Hello PDF');
      stream.endText();
      stream.close();

      final contents = page.contentStreams.toList();
      expect(contents, hasLength(1));
      final data = contents.first.encodedBytes;
      expect(data, isNotNull);
      expect(latin1.decode(data!), 'BT\n/F1 12 Tf\n72 700 Td\n(Hello PDF) Tj\nET\n');
    });

    test('appends new stream when using append mode', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final original = PDStream.fromBytes(
        Uint8List.fromList(latin1.encode('BT\n(Original) Tj\nET\n')),
      );
      page.setContentStream(original);

      final fontResource = COSName.get('F1');
      final stream = PDPageContentStream(
        document,
        page,
        mode: PDPageContentMode.append,
      );
      stream.resources.registerStandard14Font(fontResource, 'Helvetica');

      stream.beginText();
      stream.setFont(fontResource, 10);
      stream.newLineAtOffset(50, 600);
      stream.showText('Appended');
      stream.endText();
      stream.close();

      final contents = page.contentStreams.toList();
      expect(contents, hasLength(2));
      expect(latin1.decode(contents.first.encodedBytes!), 'BT\n(Original) Tj\nET\n');
      expect(
        latin1.decode(contents.last.encodedBytes!),
        'BT\n/F1 10 Tf\n50 600 Td\n(Appended) Tj\nET\n',
      );
    });

    test('prepends content when using prepend mode', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final original = PDStream.fromBytes(
        Uint8List.fromList(latin1.encode('BT\n(Original) Tj\nET\n')),
      );
      page.setContentStream(original);

      final fontResource = COSName.get('F1');
      final stream = PDPageContentStream(
        document,
        page,
        mode: PDPageContentMode.prepend,
      );
      stream.resources.registerStandard14Font(fontResource, 'Helvetica');

      stream.beginText();
      stream.setFont(fontResource, 9);
      stream.newLineAtOffset(20, 500);
      stream.showText('First');
      stream.endText();
      stream.close();

      final contents = page.contentStreams.toList();
      expect(contents, hasLength(2));
      expect(
        latin1.decode(contents.first.encodedBytes!),
        'BT\n/F1 9 Tf\n20 500 Td\n(First) Tj\nET\n',
      );
      expect(latin1.decode(contents.last.encodedBytes!), 'BT\n(Original) Tj\nET\n');
    });

    test('writes graphics operators and raw commands', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final stream = PDPageContentStream(document, page);
      stream.writeComment('Rectangle example');
      stream.saveGraphicsState();
      stream.setLineWidth(2.5);
      stream.setStrokingColorRgb(0.1, 0.2, 0.3);
      stream.rectangle(10, 20, 30, 40);
      stream.stroke();
  stream.restoreGraphicsState();
  stream.writeRaw('0.9 0.1 0.1 rg\n');
      stream.rectangle(100, 150, 50, 25);
      stream.fill();
      stream.close();

      final data = page.contentStreams.single.encodedBytes;
      expect(data, isNotNull);
      expect(
        latin1.decode(data!),
        '%Rectangle example\n'
        'q\n'
        '2.5 w\n'
        '0.1 0.2 0.3 RG\n'
        '10 20 30 40 re\n'
        'S\n'
        'Q\n'
        '0.9 0.1 0.1 rg\n'
        '100 150 50 25 re\n'
        'f\n',
      );
    });

        test('emits TJ operator with positioning array', () {
          final document = PDDocument();
          final page = PDPage();
          document.addPage(page);

          final fontResource = COSName.get('F1');
          final stream = PDPageContentStream(document, page);
          stream.resources.registerStandard14Font(fontResource, 'Helvetica');

          stream.beginText();
          stream.setFont(fontResource, 11);
          stream.showTextWithPositioning(['Hello', -120, 'World']);
          stream.endText();
          stream.close();

          final data = page.contentStreams.single.encodedBytes;
          expect(data, isNotNull);
          expect(
            latin1.decode(data!),
            'BT\n/F1 11 Tf\n[(Hello) -120 (World)] TJ\nET\n',
          );
        });

        test('writes Bézier curve operators', () {
          final document = PDDocument();
          final page = PDPage();
          document.addPage(page);

          final stream = PDPageContentStream(document, page);
          stream.moveTo(0, 0);
          stream.curveTo(10, 10, 20, 20, 30, 30);
          stream.curveToV(40, 40, 50, 50);
          stream.curveToY(60, 60, 70, 70);
          stream.stroke();
          stream.close();

          final data = page.contentStreams.single.encodedBytes;
          expect(data, isNotNull);
          expect(
            latin1.decode(data!),
            '0 0 m\n'
            '10 10 20 20 30 30 c\n'
            '40 40 50 50 v\n'
            '60 60 70 70 y\n'
            'S\n',
          );
        });

        test('setAutoLeading applies factor to font size', () {
          final document = PDDocument();
          final page = PDPage();
          document.addPage(page);

          final stream = PDPageContentStream(document, page);
          stream.setAutoLeading(12);
          stream.close();

          final data = page.contentStreams.single.encodedBytes;
          expect(data, isNotNull);
          expect(latin1.decode(data!), '14.4 TL\n');
        });

        test('showParagraph emits lines with trailing breaks', () {
          final document = PDDocument();
          final page = PDPage();
          document.addPage(page);

          final stream = PDPageContentStream(document, page);
          stream.beginText();
          stream.setLeading(14);
          stream.showParagraph('First line\nSecond line', trailingLineBreaks: 2);
          stream.endText();
          stream.close();

          final data = page.contentStreams.single.encodedBytes;
          expect(data, isNotNull);
          expect(
            latin1.decode(data!),
            'BT\n14 TL\n(First line) Tj\nT*\n(Second line) Tj\nT*\nT*\nET\n',
          );
        });

        test('writes cm transform and Do image operators', () {
          final document = PDDocument();
          final page = PDPage();
          document.addPage(page);

          final imageName = COSName.get('Im1');
          final stream = PDPageContentStream(document, page);
          stream.transform(1, 0, 0, 1, 10, 20);
          stream.drawImage(imageName);
          stream.close();

          final data = page.contentStreams.single.encodedBytes;
          expect(data, isNotNull);
          expect(
            latin1.decode(data!),
            '1 0 0 1 10 20 cm\n/Im1 Do\n',
          );
        });

    test('append mode with no content leaves page unchanged', () {
      final document = PDDocument();
      final page = PDPage();
      document.addPage(page);

      final originalBytes = Uint8List.fromList(latin1.encode('BT\n(Test) Tj\nET\n'));
      page.setContentStream(PDStream.fromBytes(originalBytes));

      final stream = PDPageContentStream(
        document,
        page,
        mode: PDPageContentMode.append,
      );
      stream.close();

      final contents = page.contentStreams.toList();
      expect(contents, hasLength(1));
      expect(latin1.decode(contents.first.encodedBytes!), 'BT\n(Test) Tj\nET\n');
    });
  });
}

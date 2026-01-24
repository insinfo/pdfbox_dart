import 'dart:io';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/text/pdf_text_stripper.dart';

void main() {
  final pdfDir = Directory('test/tmp/pdfs');
  final textDir = Directory('test/tmp/text');
  final actualDir = Directory('test/tmp/actual_text');

  if (!pdfDir.existsSync()) {
    test('Goldens text: missing test/tmp/pdfs', () {},
        skip: 'No golden PDFs found (see test/tmp/README.md)');
    return;
  }

  final pdfs = pdfDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.pdf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (pdfs.isEmpty) {
    test('Goldens text: empty test/tmp/pdfs', () {},
        skip: 'No golden PDFs found (see test/tmp/README.md)');
    return;
  }

  for (final pdfFile in pdfs) {
    final baseName = pdfFile.uri.pathSegments.last;
    final expectedTextFile = File('${textDir.path}/$baseName.txt');

    test('Golden text: $baseName', () async {
      final expected = _normalizeText(expectedTextFile.readAsStringSync());

      final doc = PDDocument.loadFromFile(pdfFile);
      try {
        final stripper = PDFTextStripper();
        final actualText = await stripper.getText(doc);
        final actual = _normalizeText(actualText);

        actualDir.createSync(recursive: true);
        final outActual = File('${actualDir.path}/$baseName.txt');
        outActual.writeAsStringSync(actualText);

        if (actual != expected) {
          fail('Golden text mismatch for $baseName. '
              'expected=${expectedTextFile.path}; actual=${outActual.path}');
        }
      } finally {
        doc.close();
      }
    },
        skip: expectedTextFile.existsSync()
            ? null
            : 'Missing golden text: ${expectedTextFile.path}');
  }
}

String _normalizeText(String text) {
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

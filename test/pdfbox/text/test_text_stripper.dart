import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:pdfbox_dart/pdfbox_dart.dart';

// Logger LOG = Logger('TestTextStripper');

void main() {
  group('TestTextStripper', () {
    late PDFTextStripper stripper;
    setUp(() {
      stripper = PDFTextStripper();
      stripper.lineSeparator = '\n';
    });

    int skipWhitespace(List<int> array, int index) {
      if (index < array.length && (array[index] == 32 || array[index] > 256)) {
        while (index < array.length && (array[index] == 32 || array[index] > 256)) {
          index++;
        }
        index--;
      }
      return index;
    }

    bool stringsEqual(String? expected, String? actual) {
      bool equals = true;
      if (expected == null && actual == null) {
        return true;
      } else if (expected != null && actual != null) {
        expected = expected.trim();
        actual = actual.trim();
        List<int> expectedArray = expected.runes.toList();
        List<int> actualArray = actual.runes.toList();
        int expectedIndex = 0;
        int actualIndex = 0;
        while (expectedIndex < expectedArray.length &&
            actualIndex < actualArray.length) {
          if (expectedArray[expectedIndex] != actualArray[actualIndex]) {
            equals = false;
            break;
          }
          expectedIndex = skipWhitespace(expectedArray, expectedIndex);
          actualIndex = skipWhitespace(actualArray, actualIndex);
          expectedIndex++;
          actualIndex++;
        }
        if (equals) {
          if (expectedIndex != expectedArray.length) {
            equals = false;
          }
          if (actualIndex != actualArray.length) {
            equals = false;
          }
          if (expectedArray.length != actualArray.length) {
            equals = false;
          }
        }
      } else {
        equals = (expected == null && actual != null && actual.trim().isEmpty) ||
            (actual == null && expected != null && expected.trim().isEmpty);
      }
      return equals;
    }

    Future<void> compareResult(File expectedFile, File outFile, File inFile,
        bool bSort, File diffFile) async {
      bool localFail = false;

      List<String> expectedLines = await expectedFile.readAsLines();
      List<String> actualLines = await outFile.readAsLines();

      // Filter blank lines to match Java behavior
      List<String> expectedLinesFiltered =
          expectedLines.where((l) => l.trim().isNotEmpty).toList();
      List<String> actualLinesFiltered =
          actualLines.where((l) => l.trim().isNotEmpty).toList();

      int maxFiltered =
          math.max(expectedLinesFiltered.length, actualLinesFiltered.length);

      for (int i = 0; i < maxFiltered; i++) {
        String? expectedLine =
            i < expectedLinesFiltered.length ? expectedLinesFiltered[i] : null;
        String? actualLine =
            i < actualLinesFiltered.length ? actualLinesFiltered[i] : null;

        if (!stringsEqual(expectedLine, actualLine)) {
          localFail = true;
        }
      }

      if (!localFail) {
        await outFile.delete();
      }
      
      if (localFail) {
        fail("File comparison failed for ${inFile.path}");
      }
    }

    Future<void> doTestFile(
        File inFile, Directory outDir, bool bLogResult, bool bSort) async {
      if (bSort) {
      } else {
      }

      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      PDDocument document = PDDocument.loadFromFile(inFile);
      try {
        File outFile;
        File diffFile;
        File expectedFile;

        String filename = inFile.uri.pathSegments.last;

        if (bSort) {
          outFile = File('${outDir.path}/$filename-sorted.txt');
          diffFile = File('${outDir.path}/$filename-sorted-diff.txt');
          expectedFile = File('${inFile.parent.path}/$filename-sorted.txt');
        } else {
          outFile = File('${outDir.path}/$filename.txt');
          diffFile = File('${outDir.path}/$filename-diff.txt');
          expectedFile = File('${inFile.parent.path}/$filename.txt');
        }

        if (await diffFile.exists()) {
          await diffFile.delete();
        }

        IOSink sink = outFile.openWrite(encoding: utf8);
        // Write BOM
        sink.add([0xEF, 0xBB, 0xBF]);

        stripper.sortByPosition = bSort;
        await stripper.writeText(document, sink);
        await sink.flush();
        await sink.close();

        if (bLogResult) {
        }

        if (!await expectedFile.exists()) {
          fail("Input verification file does not exist");
        } else {
          await compareResult(expectedFile, outFile, inFile, bSort, diffFile);
        }
      } finally {
        document.close();
      }
    }

    test('testExtract', () async {
      // String filename = System.getProperty("org.apache.pdfbox.util.TextStripper.file");
      String? filename = "cweb.pdf"; // = "eu-001.pdf"; // Uncomment to test single file

      Directory inDir = Directory('test/resources/input');
      Directory outDir = Directory('test/output');

      // ignore: unnecessary_null_comparison
      if (filename == null) {
        if (await inDir.exists()) {
          await for (var entity in inDir.list()) {
            if (entity is File && entity.path.endsWith('.pdf')) {
              // Test without sorting
              await doTestFile(entity, outDir, false, false);
              // Test with sorting
              await doTestFile(entity, outDir, false, true);
            }
          }
        }
      } else {
        File testFile = File('${inDir.path}/$filename');
        if (await testFile.exists()) {
          await doTestFile(testFile, outDir, true, false);
          await doTestFile(testFile, outDir, true, true);
        }
      }
    }, timeout: Timeout(Duration(minutes: 10)));

    test('testStartEndPage', () async {
      File pdfFile = File('test/resources/input/eu-001.pdf');
      PDDocument doc = PDDocument.loadFromFile(pdfFile);
      try {
        stripper.startPage = 2;
        stripper.endPage = 2;
        String text = (await stripper.getText(doc)).trim();
        expect(text.startsWith("Pesticides"), isTrue);
        expect(text.endsWith("1 000 10 10"), isTrue);
        expect(text.replaceAll("\r", "").length, 1378);
      } finally {
        doc.close();
      }
    });
  });
}


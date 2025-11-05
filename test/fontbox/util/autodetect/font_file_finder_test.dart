import 'dart:io';

import 'package:pdfbox_dart/src/fontbox/util/autodetect/font_dir_finder.dart';
import 'package:pdfbox_dart/src/fontbox/util/autodetect/font_file_finder.dart';
import 'package:test/test.dart';

class _TestFontDirFinder implements FontDirFinder {
  _TestFontDirFinder(this.directories);

  final List<Directory> directories;

  @override
  List<Directory> find() => directories;
}

void main() {
  group('FontFileFinder', () {
    late Directory tempRoot;
    late Directory fontsDir;
    late Directory nestedDir;
    late File ttf;
    late File otf;
    late File pfb;
    late File ttc;
    late File excluded;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('font_file_finder_test');
      fontsDir = Directory('${tempRoot.path}${Platform.pathSeparator}fonts')
        ..createSync(recursive: true);
      nestedDir = Directory('${fontsDir.path}${Platform.pathSeparator}nested')
        ..createSync(recursive: true);
      final hiddenDir = Directory('${fontsDir.path}${Platform.pathSeparator}.hidden')
        ..createSync(recursive: true);
      File('${hiddenDir.path}${Platform.pathSeparator}ignored.ttf')
        ..writeAsStringSync('');

      ttf = File('${fontsDir.path}${Platform.pathSeparator}font_a.ttf')
        ..writeAsStringSync('');
      otf = File('${fontsDir.path}${Platform.pathSeparator}font_b.OTF')
        ..writeAsStringSync('');
      pfb = File('${nestedDir.path}${Platform.pathSeparator}font_c.pfb')
        ..writeAsStringSync('');
      ttc = File('${nestedDir.path}${Platform.pathSeparator}font_d.ttc')
        ..writeAsStringSync('');
      excluded = File('${fontsDir.path}${Platform.pathSeparator}fonts.dir')
        ..writeAsStringSync('should be ignored');
      File('${fontsDir.path}${Platform.pathSeparator}notes.txt')
        ..writeAsStringSync('');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('uses provided FontDirFinder to locate fonts', () {
  final finder = FontFileFinder(dirFinder: _TestFontDirFinder([fontsDir]));
      final results = finder.find();
      final paths = results
          .map((uri) => uri.toFilePath(windows: Platform.isWindows))
          .toSet();
      expect(
        paths,
        containsAll(<String>[ttf.path, otf.path, pfb.path, ttc.path]),
      );
      expect(paths, isNot(contains(excluded.path)));
    });

    test('find accepts explicit directory path', () {
      final finder = FontFileFinder(dirFinder: _TestFontDirFinder([]));
      final results = finder.find(fontsDir.path);
      expect(
        results.map((uri) => uri.toFilePath(windows: Platform.isWindows)).toSet(),
        containsAll(<String>[ttf.path, otf.path, pfb.path, ttc.path]),
      );
    });

    test('non-existent directory yields empty result', () {
      final finder = FontFileFinder(dirFinder: _TestFontDirFinder([]));
      expect(finder.find('${tempRoot.path}${Platform.pathSeparator}missing'), isEmpty);
    });
  });
}

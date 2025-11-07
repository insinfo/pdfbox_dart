import 'package:pdfbox_dart/src/fontbox/ttf/gsub/default_gsub_worker.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_factory.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_bengali.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_devanagari.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_gujarati.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/gsub/gsub_worker_for_latin.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('GsubWorkerFactory', () {
    final factory = GsubWorkerFactory();
    final cmap = FakeCMapLookup(const <int, int>{});

    test('creates Bengali worker', () {
      final data = buildGsubData(Language.bengali, 'beng');
      expect(factory.getGsubWorker(cmap, data), isA<GsubWorkerForBengali>());
    });

    test('creates Devanagari worker', () {
      final data = buildGsubData(Language.devanagari, 'deva');
      expect(factory.getGsubWorker(cmap, data), isA<GsubWorkerForDevanagari>());
    });

    test('creates Gujarati worker', () {
      final data = buildGsubData(Language.gujarati, 'gujr');
      expect(factory.getGsubWorker(cmap, data), isA<GsubWorkerForGujarati>());
    });

    test('creates Latin worker', () {
      final data = buildGsubData(Language.latin, 'latn');
      expect(factory.getGsubWorker(cmap, data), isA<GsubWorkerForLatin>());
    });

    test('falls back to default worker', () {
      final data = buildGsubData(Language.unspecified, 'DFLT');
      expect(factory.getGsubWorker(cmap, data), isA<DefaultGsubWorker>());
    });
  });
}

import 'dart:io';

import 'package:test/test.dart';

import 'image_test_utils.dart';

class _GoldenCase {
  final String name;
  final String directory;
  final String codestreamFile;
  final String referenceFile;
  final int maxAbsError;

  const _GoldenCase(this.name, this.directory, this.codestreamFile, this.referenceFile, this.maxAbsError);
}

const _goldenCases = <_GoldenCase>[
  _GoldenCase(
    'rainbowbars_lossless',
    'resources/j2k_tests/synthetic/rainbowbars',
    'barras_rgb_lossless.jp2',
    'barras_rgb_lossless_reference.ppm',
    0,
  ),
  _GoldenCase(
    'gradient_8bit_lossless',
    'resources/j2k_tests/synthetic/gradient_8bit',
    'gradient_8bit_lossless.jp2',
    'gradient_8bit_lossless_reference.pgm',
    0,
  ),
];

void main() {
  group('JJ2000 golden vectors', () {
    for (final testCase in _goldenCases) {
      test('${testCase.name} egale referência OpenJPEG', () async {
        final baseDir = Directory(testCase.directory);
        if (!baseDir.existsSync()) {
          fail('Diretório de teste ausente: ${testCase.directory}');
        }

        final codestream = File('${testCase.directory}/${testCase.codestreamFile}');
        final referenceFile = File('${testCase.directory}/${testCase.referenceFile}');

        if (!codestream.existsSync() || !referenceFile.existsSync()) {
          fail('Arquivos necessários ausentes em ${testCase.directory}. Rode os scripts de geração primeiro.');
        }

        final referenceImage = await loadPortableImage(referenceFile);
        final outputExtension = referenceFile.path.toLowerCase().endsWith('.pgm') ? '.pgm' : '.ppm';
        final decodedImage = await decodeCodestreamWithJj2000(
          codestream,
          outputExtension: outputExtension,
        );

        expectImagesAlmostEqual(decodedImage, referenceImage, maxAbsError: testCase.maxAbsError);
      });
    }
  });
}

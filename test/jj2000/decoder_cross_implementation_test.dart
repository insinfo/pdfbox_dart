import 'dart:io';

import 'package:test/test.dart';

import 'image_test_utils.dart';

class _CrossCase {
  final String name;
  final String directory;
  final String codestreamFile;
  final String referenceFile;
  final int maxAbsError;

  const _CrossCase(this.name, this.directory, this.codestreamFile, this.referenceFile, this.maxAbsError);
}

const _crossCases = <_CrossCase>[
  _CrossCase(
    'rainbowbars_lossy',
    'resources/j2k_tests/synthetic/rainbowbars',
    'barras_rgb_lossy.jp2',
    'barras_rgb_lossy_reference.ppm',
    1,
  ),
  _CrossCase(
    'gradient_8bit_lossy',
    'resources/j2k_tests/synthetic/gradient_8bit',
    'gradient_8bit_lossy.jp2',
    'gradient_8bit_lossy_reference.pgm',
    1,
  ),
];

void main() {
  group('JJ2000 cross-implementation (OpenJPEG referência)', () {
    for (final testCase in _crossCases) {
      test('${testCase.name} dentro da tolerância OpenJPEG', () async {
        final codestream = File('${testCase.directory}/${testCase.codestreamFile}');
        final reference = File('${testCase.directory}/${testCase.referenceFile}');

        if (!codestream.existsSync() || !reference.existsSync()) {
          fail('Arquivos necessários ausentes em ${testCase.directory}. Rode os scripts antes de executar os testes.');
        }

        final referenceImage = await loadPortableImage(reference);
        final outputExtension = reference.path.toLowerCase().endsWith('.pgm') ? '.pgm' : '.ppm';
        final decodedImage = await decodeCodestreamWithJj2000(
          codestream,
          outputExtension: outputExtension,
        );

        expectImagesAlmostEqual(decodedImage, referenceImage, maxAbsError: testCase.maxAbsError);
      });
    }
  });
}

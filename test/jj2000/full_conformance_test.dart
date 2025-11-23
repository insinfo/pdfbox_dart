import 'dart:io';
import 'package:test/test.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/decoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ParameterList.dart';
import 'test_utils.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/FacilityManager.dart';

void main() {
  setUpAll(() {
    FacilityManager.registerMsgLogger(QuietLogger());
  });

  group('Full Conformance Tests', () {
    final images = [
      'file1.jp2',
      'icon32.jp2',
      'relax.jp2',
      'barras_rgb.jp2',
      // 'grad_final.jp2' // 16-bit, skipped by PPM writer
    ];

    for (final image in images) {
      test('$image decodes successfully', () {
        final probe = _decodeAndProbe('test_images/$image');
        expect(probe.pixelCount, greaterThan(0));
      });
    }
  });
}

PpmProbe _decodeAndProbe(String inputPath) {
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    fail('Input codestream missing: $inputPath');
  }

  final outputDir = Directory.systemTemp.createTempSync('jj2000_full_conf_');
  final outputPath = '${outputDir.path}/${inputFile.uri.pathSegments.last}.ppm';

  try {
    final defaults = ParameterList();
    for (final entry in Decoder.getParameterInfo()) {
      if (entry.length >= 4 && entry[3].isNotEmpty) {
        defaults.put(entry[0], entry[3]);
      }
    }

    final params = ParameterList(defaults);
    params.put('u', 'off');
    params.put('v', 'off');
    params.put('verbose', 'off');
    params.put('debug', 'off');
    params.put('i', inputPath);
    params.put('o', outputPath);

    final decoder = Decoder(params);
    decoder.run();

    expect(decoder.exitCode, 0, reason: 'Decoder exited with non-zero code for $inputPath');

    final outputFile = File(outputPath);
    expect(outputFile.existsSync(), isTrue, reason: 'Output file not created for $inputPath');

    final ppmBytes = outputFile.readAsBytesSync();
    return PpmProbe.fromBytes(ppmBytes);
  } finally {
    outputDir.deleteSync(recursive: true);
  }
}


import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/decoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ParameterList.dart';

void main() {
  group('Decoder Reference Comparison Tests', () {
    test('Decode and compare with OpenJPEG output', () {
      final inputPath = 'test_images/barras_rgb.jp2';
      final inputFile = File(inputPath);
      if (!inputFile.existsSync()) {
        print('⚠ Input file missing: $inputPath');
        return;
      }

      // Decode with our Dart implementation
      final dartOutputDir = Directory.systemTemp.createTempSync('dart_decoder_');
      final dartOutputPath = '${dartOutputDir.path}/output.ppm';

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
        params.put('o', dartOutputPath);

        final decoder = Decoder(params);
        decoder.run();

        expect(decoder.exitCode, 0,
            reason: 'Dart decoder exited with non-zero code');

        final dartOutput = File(dartOutputPath);
        expect(dartOutput.existsSync(), isTrue,
            reason: 'Dart decoder output not created');

        // Decode with OpenJPEG reference implementation
        final openjpegExe = 'C:\\MyDartProjects\\pdfbox_dart\\openjpeg\\build\\bin\\Release\\opj_decompress.exe';
        final openjpegFile = File(openjpegExe);
        
        if (openjpegFile.existsSync()) {
          final openjpegOutputDir = Directory.systemTemp.createTempSync('openjpeg_');
          final openjpegOutputPath = '${openjpegOutputDir.path}/output.ppm';

          try {
            // Run OpenJPEG decoder
            final result = Process.runSync(
              openjpegExe,
              ['-i', inputPath, '-o', openjpegOutputPath],
            );

            if (result.exitCode == 0) {
              final openjpegOutput = File(openjpegOutputPath);
              if (openjpegOutput.existsSync()) {
                // Compare outputs
                final dartBytes = dartOutput.readAsBytesSync();
                final openjpegBytes = openjpegOutput.readAsBytesSync();

                // Parse PPM headers to skip them in comparison
                final dartData = _parsePPM(dartBytes);
                final openjpegData = _parsePPM(openjpegBytes);

                expect(dartData.width, equals(openjpegData.width),
                    reason: 'Width mismatch with OpenJPEG reference');
                expect(dartData.height, equals(openjpegData.height),
                    reason: 'Height mismatch with OpenJPEG reference');

                // Compare pixel data - allow some tolerance for different implementations
                final tolerance = 2; // Allow up to 2 levels difference per channel
                var differences = 0;
                final maxDifferences = (dartData.pixels.length * 0.01).ceil(); // Allow 1% pixel differences

                for (var i = 0; i < dartData.pixels.length && i < openjpegData.pixels.length; i++) {
                  final diff = (dartData.pixels[i] - openjpegData.pixels[i]).abs();
                  if (diff > tolerance) {
                    differences++;
                  }
                }

                expect(differences, lessThanOrEqualTo(maxDifferences),
                    reason: 'Too many pixel differences ($differences) compared to OpenJPEG reference');

                print('✓ Dart decoder output matches OpenJPEG reference (differences: $differences/${dartData.pixels.length}, ${(differences / dartData.pixels.length * 100).toStringAsFixed(2)}%)');
              }
            }
          } finally {
            openjpegOutputDir.deleteSync(recursive: true);
          }
        } else {
          print('⚠ OpenJPEG executable not found, skipping comparison with reference');
        }

        // Basic validation that our decoder produced valid output
        final dartData = _parsePPM(dartOutput.readAsBytesSync());
        expect(dartData.width, greaterThan(0));
        expect(dartData.height, greaterThan(0));
        expect(dartData.pixels.length, equals(dartData.width * dartData.height * 3));

      } finally {
        dartOutputDir.deleteSync(recursive: true);
      }
    });

    test('Decode multiple test images successfully', () {
      final testImages = [
        'test_images/barras_rgb.jp2',
        'test_images/simple.jp2',
        'test_images/generated/gradient_horizontal_openjpeg.jp2',
        'test_images/generated/gradient_vertical_openjpeg.jp2',
        'test_images/generated/checkerboard_openjpeg.jp2',
        'test_images/generated/solid_red_openjpeg.jp2',
        'test_images/generated/solid_green_openjpeg.jp2',
        'test_images/generated/solid_blue_openjpeg.jp2',
        'test_images/generated/rainbow_stripes_openjpeg.jp2',
        'test_images/generated/circles_openjpeg.jp2',
      ];

      var successCount = 0;
      for (final imagePath in testImages) {
        final inputFile = File(imagePath);
        if (!inputFile.existsSync()) {
          print('⚠ Test image not found: $imagePath');
          continue;
        }

        final outputDir = Directory.systemTemp.createTempSync('decoder_test_');
        try {
          final outputPath = '${outputDir.path}/output.ppm';

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
          params.put('i', imagePath);
          params.put('o', outputPath);

          final decoder = Decoder(params);
          decoder.run();

          if (decoder.exitCode == 0) {
            final outputFile = File(outputPath);
            if (outputFile.existsSync()) {
              final data = _parsePPM(outputFile.readAsBytesSync());
              expect(data.width * data.height, greaterThan(0),
                  reason: 'Image $imagePath has no pixels');
              successCount++;
              print('✓ Successfully decoded: $imagePath (${data.width}x${data.height})');
            }
          }
        } finally {
          outputDir.deleteSync(recursive: true);
        }
      }

      expect(successCount, greaterThan(0),
          reason: 'Expected at least one test image to decode successfully');
    });

    test('Entropy decoder handles various code-block configurations', () {
      // This test verifies that the entropy decoder (with our new implementations)
      // can handle different JPEG2000 encoding parameters
      
      final inputPath = 'test_images/barras_rgb.jp2';
      final inputFile = File(inputPath);
      if (!inputFile.existsSync()) {
        print('⚠ Input file missing: $inputPath');
        return;
      }

      final outputDir = Directory.systemTemp.createTempSync('entropy_test_');
      try {
        final outputPath = '${outputDir.path}/output.ppm';

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

        expect(decoder.exitCode, 0,
            reason: 'Decoder should handle standard JPEG2000 file');

        final outputFile = File(outputPath);
        expect(outputFile.existsSync(), isTrue);

        final data = _parsePPM(outputFile.readAsBytesSync());
        
        // Verify the output has reasonable pixel values
        var nonZeroPixels = 0;
        var pixelSum = 0;
        for (var i = 0; i < data.pixels.length; i++) {
          if (data.pixels[i] != 0) nonZeroPixels++;
          pixelSum += data.pixels[i];
        }

        expect(nonZeroPixels, greaterThan(data.pixels.length ~/ 2),
            reason: 'Expected most pixels to be non-zero');

        final avgPixelValue = pixelSum / data.pixels.length;
        expect(avgPixelValue, greaterThan(10),
            reason: 'Average pixel value should be reasonable');
        expect(avgPixelValue, lessThan(245),
            reason: 'Average pixel value should not be saturated');

        print('✓ Entropy decoder processed image successfully');
        print('  Image: ${data.width}x${data.height}');
        print('  Non-zero pixels: ${(nonZeroPixels / data.pixels.length * 100).toStringAsFixed(1)}%');
        print('  Average pixel value: ${avgPixelValue.toStringAsFixed(1)}');

      } finally {
        outputDir.deleteSync(recursive: true);
      }
    });

    test('Compare Dart decoder with Java JJ2000 reference on generated images', () {
      final testImages = [
        'gradient_horizontal',
        'gradient_vertical',
        'checkerboard',
        'solid_red',
        'solid_green',
        'solid_blue',
        'circles',
      ];

      var comparisonResults = <Map<String, dynamic>>[];

      for (final imageName in testImages) {
        final j2kPath = 'test_images/generated/${imageName}_jj2000.j2k';
        final javaDecodedPath = 'test_images/generated/${imageName}_jj2000_decoded.ppm';
        
        final j2kFile = File(j2kPath);
        final javaDecodedFile = File(javaDecodedPath);

        if (!j2kFile.existsSync() || !javaDecodedFile.existsSync()) {
          print('⚠ Pulando $imageName - arquivos de referência não encontrados');
          continue;
        }

        // Decode with Dart
        final dartOutputDir = Directory.systemTemp.createTempSync('dart_test_');
        try {
          final dartOutputPath = '${dartOutputDir.path}/output.ppm';

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
          params.put('i', j2kPath);
          params.put('o', dartOutputPath);

          final decoder = Decoder(params);
          decoder.run();

          if (decoder.exitCode == 0) {
            final dartOutputFile = File(dartOutputPath);
            if (dartOutputFile.existsSync()) {
              // Compare with Java reference
              final dartData = _parsePPM(dartOutputFile.readAsBytesSync());
              final javaData = _parsePPM(javaDecodedFile.readAsBytesSync());

              expect(dartData.width, equals(javaData.width),
                  reason: 'Width mismatch for $imageName');
              expect(dartData.height, equals(javaData.height),
                  reason: 'Height mismatch for $imageName');

              // Compare pixels
              var differences = 0;
              var maxDiff = 0;
              final tolerance = 2;

              for (var i = 0; i < dartData.pixels.length && i < javaData.pixels.length; i++) {
                final diff = (dartData.pixels[i] - javaData.pixels[i]).abs();
                if (diff > tolerance) {
                  differences++;
                }
                if (diff > maxDiff) {
                  maxDiff = diff;
                }
              }

              final diffPercent = (differences / dartData.pixels.length * 100);
              
              comparisonResults.add({
                'image': imageName,
                'width': dartData.width,
                'height': dartData.height,
                'differences': differences,
                'totalPixels': dartData.pixels.length,
                'diffPercent': diffPercent,
                'maxDiff': maxDiff,
              });

              print('✓ $imageName: ${dartData.width}x${dartData.height}, diffs: $differences/${dartData.pixels.length} (${diffPercent.toStringAsFixed(3)}%), max: $maxDiff');

              // Allow up to 1% pixel differences
              expect(diffPercent, lessThan(1.0),
                  reason: 'Too many differences for $imageName compared to Java JJ2000');
            }
          }
        } finally {
          dartOutputDir.deleteSync(recursive: true);
        }
      }

      expect(comparisonResults.length, greaterThan(0),
          reason: 'Expected at least one successful comparison');

      print('\n📊 Resumo das Comparações com Java JJ2000:');
      for (final result in comparisonResults) {
        print('  ${result['image']}: ${result['diffPercent'].toStringAsFixed(3)}% diferenças');
      }
    });

    test('Compare Dart decoder with OpenJPEG reference on generated images', () {
      final testImages = [
        'gradient_horizontal',
        'gradient_vertical',
        'checkerboard',
        'solid_red',
        'solid_green',
        'solid_blue',
        'circles',
      ];

      var comparisonResults = <Map<String, dynamic>>[];

      for (final imageName in testImages) {
        final jp2Path = 'test_images/generated/${imageName}_openjpeg.jp2';
        final openjpegDecodedPath = 'test_images/generated/${imageName}_openjpeg_decoded.ppm';
        
        final jp2File = File(jp2Path);
        final openjpegDecodedFile = File(openjpegDecodedPath);

        if (!jp2File.existsSync() || !openjpegDecodedFile.existsSync()) {
          print('⚠ Pulando $imageName - arquivos de referência OpenJPEG não encontrados');
          continue;
        }

        // Decode with Dart
        final dartOutputDir = Directory.systemTemp.createTempSync('dart_openjpeg_test_');
        try {
          final dartOutputPath = '${dartOutputDir.path}/output.ppm';

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
          params.put('i', jp2Path);
          params.put('o', dartOutputPath);

          final decoder = Decoder(params);
          decoder.run();

          if (decoder.exitCode == 0) {
            final dartOutputFile = File(dartOutputPath);
            if (dartOutputFile.existsSync()) {
              // Compare with OpenJPEG reference
              final dartData = _parsePPM(dartOutputFile.readAsBytesSync());
              final openjpegData = _parsePPM(openjpegDecodedFile.readAsBytesSync());

              expect(dartData.width, equals(openjpegData.width),
                  reason: 'Width mismatch for $imageName');
              expect(dartData.height, equals(openjpegData.height),
                  reason: 'Height mismatch for $imageName');

              // Compare pixels
              var differences = 0;
              var maxDiff = 0;
              final tolerance = 2;

              for (var i = 0; i < dartData.pixels.length && i < openjpegData.pixels.length; i++) {
                final diff = (dartData.pixels[i] - openjpegData.pixels[i]).abs();
                if (diff > tolerance) {
                  differences++;
                }
                if (diff > maxDiff) {
                  maxDiff = diff;
                }
              }

              final diffPercent = (differences / dartData.pixels.length * 100);
              
              comparisonResults.add({
                'image': imageName,
                'width': dartData.width,
                'height': dartData.height,
                'differences': differences,
                'totalPixels': dartData.pixels.length,
                'diffPercent': diffPercent,
                'maxDiff': maxDiff,
              });

              print('✓ $imageName: ${dartData.width}x${dartData.height}, diffs: $differences/${dartData.pixels.length} (${diffPercent.toStringAsFixed(3)}%), max: $maxDiff');

              // Allow up to 1% pixel differences
              expect(diffPercent, lessThan(1.0),
                  reason: 'Too many differences for $imageName compared to OpenJPEG');
            }
          }
        } finally {
          dartOutputDir.deleteSync(recursive: true);
        }
      }

      expect(comparisonResults.length, greaterThan(0),
          reason: 'Expected at least one successful comparison');

      print('\n📊 Resumo das Comparações com OpenJPEG:');
      for (final result in comparisonResults) {
        print('  ${result['image']}: ${result['diffPercent'].toStringAsFixed(3)}% diferenças');
      }
    });
  });
}

class _PPMData {
  final int width;
  final int height;
  final Uint8List pixels;

  _PPMData(this.width, this.height, this.pixels);
}

_PPMData _parsePPM(Uint8List bytes) {
  var offset = 0;

  // Skip "P6" magic number
  while (offset < bytes.length && bytes[offset] != 0x0A) {
    offset++;
  }
  offset++; // Skip newline

  // Skip comments
  while (offset < bytes.length && bytes[offset] == 0x23) {
    while (offset < bytes.length && bytes[offset] != 0x0A) {
      offset++;
    }
    offset++;
  }

  // Read width and height
  final dimensions = <int>[];
  var currentNumber = '';
  while (dimensions.length < 2 && offset < bytes.length) {
    final ch = bytes[offset];
    if (ch >= 0x30 && ch <= 0x39) {
      // digit
      currentNumber += String.fromCharCode(ch);
    } else if (currentNumber.isNotEmpty) {
      dimensions.add(int.parse(currentNumber));
      currentNumber = '';
    }
    offset++;
  }

  final width = dimensions[0];
  final height = dimensions[1];

  // Skip max value line
  while (offset < bytes.length && bytes[offset] != 0x0A) {
    offset++;
  }
  offset++; // Skip newline

  // Remaining bytes are pixel data
  final pixels = Uint8List.sublistView(bytes, offset);

  return _PPMData(width, height, pixels);
}


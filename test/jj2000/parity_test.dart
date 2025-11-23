import 'dart:io';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/decoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ParameterList.dart';
import 'package:test/test.dart';

void main() {
  test('Parity test', () {
    final input = Platform.environment['JJ2000_INPUT'];
    if (input == null) {
      print('Skipping parity test: JJ2000_INPUT not set');
      return;
    }

    final instrument = Platform.environment['JJ2000_INSTRUMENT'] ?? 'on';

    final args = <String>[
      '-i', input,
      '-o', 'build/parity_out.pgx',
      '-instrument', instrument,
      '-verbose', 'off',
      '-debug', 'off',
    ];
    
    final defaults = ParameterList();
    for (final opt in Decoder.getParameterInfo()) {
        if (opt.length > 3) {
            defaults.put(opt[0], opt[3]);
        }
    }
    
    final pl = ParameterList(defaults);
    pl.parseArgs(args);
    
    final decoder = Decoder(pl);
    decoder.run();
    
    if (decoder.exitCode != 0) {
      fail('Decoder exited with code ${decoder.exitCode}');
    }
  });
}


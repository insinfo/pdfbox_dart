import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/decoder/decoder.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/ParameterList.dart';

void main(List<String> args) {
  // Parse command line arguments
  final defaults = ParameterList();
  for (final entry in Decoder.getParameterInfo()) {
    if (entry.length >= 4 && entry[3].isNotEmpty) {
      defaults.put(entry[0], entry[3]);
    }
  }

  final params = ParameterList(defaults);
  
  // Parse args
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('-')) {
      final key = args[i].substring(1);
      if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
        params.put(key, args[i + 1]);
        i++;
      } else {
        params.put(key, 'on');
      }
    }
  }

  final decoder = Decoder(params);
  decoder.run();
}


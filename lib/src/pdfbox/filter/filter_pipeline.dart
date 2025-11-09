import 'dart:typed_data';

import '../../io/exceptions.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'decode_options.dart';
import 'decode_result.dart';
import 'filter_decode_result.dart';
import 'filter_factory.dart';

class FilterPipelineResult {
  FilterPipelineResult(this.data, this.results);

  final Uint8List data;
  final List<DecodeResult> results;
}

class FilterPipeline {
  FilterPipeline({
    required this.parameters,
    required this.filterNames,
    this.options = DecodeOptions.defaultOptions,
  });

  final COSDictionary parameters;
  final List<COSName> filterNames;
  final DecodeOptions options;

  FilterPipelineResult decode(Uint8List encoded) {
    var current = Uint8List.fromList(encoded);
    final results = <DecodeResult>[];

    for (var i = 0; i < filterNames.length; i++) {
      final filter = FilterFactory.instance.getFilter(filterNames[i]);
      final FilterDecodeResult outcome = filter.decode(
        current,
        parameters,
        i,
        options: options,
      );
      current = outcome.data;
      results.add(outcome.decodeResult);
    }

    return FilterPipelineResult(current, results);
  }

  Uint8List encode(Uint8List decoded) {
    var current = Uint8List.fromList(decoded);

    for (var i = filterNames.length - 1; i >= 0; i--) {
      final filter = FilterFactory.instance.getFilter(filterNames[i]);
      try {
        current = filter.encode(current, parameters, i);
      } on IOException {
        rethrow;
      } catch (error) {
        throw IOException('Failed to encode using ${filterNames[i]} - $error');
      }
    }

    return current;
  }
}

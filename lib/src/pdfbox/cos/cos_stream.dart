import 'dart:async';
import 'dart:typed_data';

import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../filter/decode_options.dart';
import '../filter/decode_result.dart';
import '../filter/filter_pipeline.dart';
import 'cos_array.dart';
import 'cos_dictionary.dart';
import 'cos_name.dart';
import 'cos_string.dart';

class COSStream extends COSDictionary {
  COSStream();

  Uint8List? _data;

  Uint8List? get data => _data == null ? null : Uint8List.fromList(_data!);

  set data(Uint8List? value) {
    _data = value == null ? null : Uint8List.fromList(value);
    if (_data != null) {
      setInt(COSName.length, _data!.length);
    } else {
      removeItem(COSName.length);
    }
  }

  Stream<List<int>> openStream() {
    final raw = encodedBytes();
    if (raw == null) {
      return const Stream<List<int>>.empty();
    }
    return Stream<List<int>>.value(raw);
  }

  Uint8List? encodedBytes({bool copy = true}) {
    if (_data == null) {
      return null;
    }
    if (copy) {
      return Uint8List.fromList(_data!);
    }
    return _data!;
  }

  RandomAccessRead createView({DecodeOptions options = DecodeOptions.defaultOptions}) {
    final decoded = decode(options: options);
    if (decoded != null) {
      return RandomAccessReadBuffer.fromBytes(decoded);
    }
    final encoded = encodedBytes(copy: true);
    if (encoded != null) {
      return RandomAccessReadBuffer.fromBytes(encoded);
    }
    return RandomAccessReadBuffer();
  }

  FilterPipelineResult? decodeWithResult({
    DecodeOptions options = DecodeOptions.defaultOptions,
  }) {
    if (_data == null) {
      return null;
    }

    if (filters.isEmpty) {
      return FilterPipelineResult(
        Uint8List.fromList(_data!),
        const <DecodeResult>[],
      );
    }

    final pipeline = FilterPipeline(
      parameters: this,
      filterNames: filters,
      options: options,
    );
    return pipeline.decode(_data!);
  }

  Uint8List? decode({DecodeOptions options = DecodeOptions.defaultOptions}) {
    final result = decodeWithResult(options: options);
    return result?.data;
  }

  List<COSName> get filters {
    final raw = getDictionaryObject(COSName.filter);
    if (raw == null) {
      return const <COSName>[];
    }
    if (raw is COSName) {
      return <COSName>[raw];
    }
    if (raw is COSArray) {
      final names = <COSName>[];
      for (final entry in raw) {
        if (entry is COSName) {
          names.add(entry);
        } else if (entry is COSString) {
          names.add(COSName(entry.string));
        }
      }
      return names;
    }
    if (raw is COSString) {
      return <COSName>[COSName(raw.string)];
    }
    return const <COSName>[];
  }
}

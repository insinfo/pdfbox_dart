import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'decode_options.dart';
import 'filter_decode_result.dart';

abstract class Filter {
  const Filter();

  FilterDecodeResult decode(
    Uint8List encoded,
    COSDictionary parameters,
    int index, {
    DecodeOptions options = DecodeOptions.defaultOptions,
  });

  Uint8List encode(Uint8List input, COSDictionary parameters);

  COSDictionary getDecodeParams(COSDictionary dictionary, int index) {
    final COSBase? filter =
        dictionary.getDictionaryObject(COSName.f, COSName.filter);
    final COSBase? obj =
        dictionary.getDictionaryObject(COSName.dp, COSName.decodeParms);
    if (filter is COSName && obj is COSDictionary) {
      return obj;
    }
    if (filter is COSArray && obj is COSArray) {
      if (index < obj.length) {
        final candidate = obj.getObject(index);
        if (candidate is COSDictionary) {
          return candidate;
        }
      }
    } else if (obj != null && filter is! COSArray && obj is! COSArray) {
      // PDFBox tolerates this scenario by returning an empty dictionary.
    }
    return COSDictionary();
  }

  int getCompressionLevel() => -1;
}

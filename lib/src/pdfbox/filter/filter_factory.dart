import '../../io/exceptions.dart';
import '../cos/cos_name.dart';
import 'ascii85_filter.dart';
import 'ascii_hex_filter.dart';
import 'dct_filter.dart';
import 'filter.dart';
import 'flate_filter.dart';
import 'lzw_filter.dart';
import 'run_length_filter.dart';

class FilterFactory {
  FilterFactory._();

  static final FilterFactory instance = FilterFactory._();

  final Map<COSName, Filter> _filters = <COSName, Filter>{
    COSName.flateDecode: const FlateFilter(),
    COSName.flateDecodeAbbreviation: const FlateFilter(),
    COSName.lzwDecode: const LZWFilter(),
    COSName.lzwDecodeAbbreviation: const LZWFilter(),
    COSName.asciiHexDecode: const ASCIIHexFilter(),
    COSName.asciiHexDecodeAbbreviation: const ASCIIHexFilter(),
    COSName.ascii85Decode: const ASCII85Filter(),
    COSName.ascii85DecodeAbbreviation: const ASCII85Filter(),
    COSName.runLengthDecode: const RunLengthFilter(),
    COSName.runLengthDecodeAbbreviation: const RunLengthFilter(),
    COSName.dctDecode: const DCTFilter(),
    COSName.dctDecodeAbbreviation: const DCTFilter(),
  };

  Filter getFilter(COSName name) {
    final filter = _filters[name];
    if (filter == null) {
      throw IOException('Unsupported filter: $name');
    }
    return filter;
  }

  bool hasFilter(COSName name) => _filters.containsKey(name);
}

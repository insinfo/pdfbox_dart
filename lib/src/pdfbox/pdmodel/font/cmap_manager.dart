import '../../../fontbox/cmap/cmap.dart';
import '../../../fontbox/cmap/cmap_parser.dart';
import '../../../io/random_access_read.dart';

/// CMap resource loader and cache mirroring the PDFBox behaviour.
class CMapManager {
  CMapManager._();

  static final Map<String, CMap> _cache = <String, CMap>{};

  /// Fetches a predefined CMap by [name], loading it from the embedded repository if required.
  static CMap getPredefinedCMap(String name) {
    final normalised = name.trim();
    final cached = _cache[normalised];
    if (cached != null) {
      return cached;
    }

    final cmap = CMapParser().parsePredefined(normalised);
    final cacheKey = cmap.name ?? normalised;
    _cache[cacheKey] = cmap;
    if (cacheKey != normalised) {
      _cache[normalised] = cmap;
    }
    return cmap;
  }

  /// Parses a CMap from the given [source].
  static CMap? parseCMap(RandomAccessRead? source) {
    if (source == null) {
      return null;
    }
    return CMapParser().parse(source);
  }
}

import '../../cos/cos_base.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';

/// Wrapper around a CIDSystemInfo dictionary.
class PDCIDSystemInfo implements COSObjectable {
  PDCIDSystemInfo(String registry, String ordering, int supplement)
      : _dictionary = COSDictionary() {
    _dictionary.setString(COSName.registry, registry);
    _dictionary.setString(COSName.ordering, ordering);
    _dictionary.setInt(COSName.supplement, supplement);
  }

  PDCIDSystemInfo.fromDictionary(COSDictionary dictionary)
      : _dictionary = dictionary;

  final COSDictionary _dictionary;

  /// Returns the underlying COS dictionary.
  COSDictionary get dictionary => _dictionary;

  /// PostScript registry name.
  String? get registry => _dictionary.getString(COSName.registry);

  /// PostScript ordering name.
  String? get ordering => _dictionary.getString(COSName.ordering);

  /// Supplement number identifying updates to the character collection.
  int? get supplement => _dictionary.getInt(COSName.supplement);

  @override
  COSBase get cosObject => _dictionary;

  @override
  String toString() => '${registry ?? 'null'}-${ordering ?? 'null'}-${supplement ?? -1}';
}

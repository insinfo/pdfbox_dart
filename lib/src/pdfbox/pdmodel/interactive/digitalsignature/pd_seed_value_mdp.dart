import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

/// Represents the certification/author signature constraint in seed values.
class PDSeedValueMDP implements COSObjectable {
  PDSeedValueMDP([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary() {
    if (dictionary != null) {
      _dictionary.isDirect = true;
    }
  }

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  int get p => _dictionary.getInt(COSName.p) ?? 0;

  void setP(int value) {
    if (value < 0 || value > 3) {
      throw ArgumentError.value(value, 'value', 'Only values between 0 and 3 are allowed');
    }
    _dictionary.setInt(COSName.p, value);
  }

  int getP() => p;

  void setCertificationPermission(int value) => setP(value);

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict.isDirect = true;
    return dict;
  }
}
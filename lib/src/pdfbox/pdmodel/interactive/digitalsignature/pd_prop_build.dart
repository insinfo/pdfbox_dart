import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import 'pd_prop_build_data_dict.dart';

/// Minimal representation of the signature build dictionary.
class PDPropBuild implements COSObjectable {
  PDPropBuild([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  PDPropBuildDataDict? get filter {
    final dict = _dictionary.getCOSDictionary(COSName.filter);
    return dict == null ? null : PDPropBuildDataDict(dict);
  }

  set filter(PDPropBuildDataDict? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.filter);
    } else {
      _dictionary[COSName.filter] = value;
    }
  }

  PDPropBuildDataDict? get pubSec {
    final dict = _dictionary.getCOSDictionary(COSName.pubSec);
    return dict == null ? null : PDPropBuildDataDict(dict);
  }

  set pubSec(PDPropBuildDataDict? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.pubSec);
    } else {
      _dictionary[COSName.pubSec] = value;
    }
  }

  PDPropBuildDataDict? get app {
    final dict = _dictionary.getCOSDictionary(COSName.app);
    return dict == null ? null : PDPropBuildDataDict(dict);
  }

  set app(PDPropBuildDataDict? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.app);
    } else {
      _dictionary[COSName.app] = value;
    }
  }

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict.isDirect = true;
    return dict;
  }
}

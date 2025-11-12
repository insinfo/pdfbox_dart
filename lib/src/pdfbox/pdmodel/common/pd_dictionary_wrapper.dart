import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';

/// Simple wrapper around a [COSDictionary] used by higher-level PD classes.
class PDDictionaryWrapper implements COSObjectable {
  PDDictionaryWrapper([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  COSDictionary get dictionary => _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  @override
  bool operator ==(Object other) =>
      other is PDDictionaryWrapper && other._dictionary == _dictionary;

  @override
  int get hashCode => _dictionary.hashCode;
}

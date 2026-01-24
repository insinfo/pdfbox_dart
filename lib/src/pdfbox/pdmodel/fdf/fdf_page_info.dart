import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';

/// This represents an FDF page info that is part of the FDF page.
class FDFPageInfo implements COSObjectable {
  final COSDictionary _pageInfo;

  /// Default constructor.
  FDFPageInfo() : _pageInfo = COSDictionary();

  /// Constructor with an existing dictionary.
  FDFPageInfo.fromDictionary(this._pageInfo);

  @override
  COSDictionary get cosObject => _pageInfo;
}

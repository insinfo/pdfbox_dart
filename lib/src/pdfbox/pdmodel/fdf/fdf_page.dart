import '../../cos/cos_array.dart';
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../common/cos_objectable.dart';
import 'fdf_template.dart';
import 'fdf_page_info.dart';

/// This represents an FDF page that is part of the FDF document.
class FDFPage implements COSObjectable {
  final COSDictionary _page;

  /// Default constructor.
  FDFPage([COSDictionary? p]) : _page = p ?? COSDictionary();

  /// Convert this standard java object to a COS object.
  @override
  COSDictionary get cosObject => _page;

  /// This will get a list of FDFTemplate objects that describe the named pages that serve as templates.
  ///
  /// Returns a list of templates.
  List<FDFTemplate>? getTemplates() {
    COSArray? array = _page.getCOSArray(COSName.templates);
    if (array != null) {
      List<FDFTemplate> objects = [];
      for (int i = 0; i < array.length; i++) {
        objects.add(FDFTemplate.fromDictionary(array.getObject(i) as COSDictionary));
      }
      return objects;
    }
    return null;
  }

  /// A list of FDFTemplate objects.
  ///
  /// [templates] A list of templates for this Page.
  void setTemplates(List<FDFTemplate> templates) {
    _page.setItem(COSName.templates, COSArray(templates.map((e) => e.cosObject).toList()));
  }

  /// This will get the FDF page info object.
  ///
  /// Returns The Page info.
  FDFPageInfo? getPageInfo() {
    FDFPageInfo? retval;
    COSDictionary? dict = _page.getCOSDictionary(COSName.info);
    if (dict != null) {
      retval = FDFPageInfo.fromDictionary(dict);
    }
    return retval;
  }

  /// This will set the page info.
  ///
  /// [info] The new page info dictionary.
  void setPageInfo(FDFPageInfo info) {
    _page.setItem(COSName.info, info);
  }
}


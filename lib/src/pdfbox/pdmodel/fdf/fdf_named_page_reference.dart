import '../../../io/exceptions.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../common/pd_file_specification.dart';

/// This represents an FDF named page reference that is part of the FDF field.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFNamedPageReference
class FDFNamedPageReference implements COSObjectable {
  FDFNamedPageReference([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  /// This will get the name of the referenced page. A required parameter.
  /// Returns the name of the referenced page.
  String? get name => _dictionary.getString(COSName.get('NAME'));

  /// This will set the name of the referenced page.
  /// [name] The referenced page name.
  set name(String? name) {
    _dictionary.setString(COSName.get('NAME'), name);
  }

  /// This will get the file specification of this reference. An optional parameter.
  /// Returns the F entry for this dictionary or null.
  /// Throws IOException if there is an error creating the file spec.
  PDFileSpecification? getFileSpecification() {
    try {
      return PDFileSpecification.fromCOS(_dictionary.getDictionaryObject(COSName.f));
    } catch (e) {
      throw IOException('Error creating file specification: $e');
    }
  }

  /// This will set the file specification for this named page reference.
  /// [fs] The file specification to set.
  void setFileSpecification(PDFileSpecification? fs) {
    _dictionary.setItem(COSName.f, fs);
  }
}

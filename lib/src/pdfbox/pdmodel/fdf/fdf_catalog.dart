import '../../../io/exceptions.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../interactive/digitalsignature/pd_signature.dart';
import 'fdf_dictionary.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';

/// FDF catalog that is part of the FDF document.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFCatalog
class FDFCatalog implements COSObjectable {
  FDFCatalog([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  /// Constructor from XFDF XML root element.
  FDFCatalog.fromXml(XmlElement element) : _dictionary = COSDictionary() {
    final fdfDict = FDFDictionary.fromXml(element);
    setFdf(fdfDict);
  }

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  /// This will get the version that was specified in the catalog dictionary.
  /// Returns the FDF version.
  String? get version => _dictionary.getNameAsString(COSName.version);

  /// This will set the version of the FDF document.
  /// [version] The new version for the FDF document.
  set version(String? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.version);
    } else {
      _dictionary.setName(COSName.version, value);
    }
  }

  /// This will get the FDF dictionary.
  /// Returns the FDF dictionary.
  FDFDictionary get fdf {
    final existing = _dictionary.getCOSDictionary(COSName.fdf);
    if (existing != null) {
      return FDFDictionary(existing);
    }
    final created = FDFDictionary();
    setFdf(created);
    return created;
  }

  /// This will set the FDF document.
  /// [fdf] The new FDF dictionary.
  void setFdf(FDFDictionary fdf) {
    _dictionary.setItem(COSName.fdf, fdf);
  }

  /// This will get the signature or null if there is none.
  /// Returns the signature.
  PDSignature? get signature {
    final sig = _dictionary.getCOSDictionary(COSName.sig);
    return sig != null ? PDSignature(sig) : null;
  }

  /// This will set the signature that is associated with this catalog.
  /// [sig] The new signature.
  set signature(PDSignature? sig) {
    _dictionary.setItem(COSName.sig, sig);
  }

  /// This will write this element as an XML document.
  /// [output] The stream to write the xml to.
  /// Throws IOException if there is an error writing the XML.
  void writeXML(StringSink output) {
    try {
      fdf.writeXML(output);
    } catch (e) {
      throw IOException('Error writing FDF catalog XML: $e');
    }
  }
}


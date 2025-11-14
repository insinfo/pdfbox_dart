import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../pdmodel/fdf/fdf_document.dart';
import 'cos_parser.dart';

/// Parser for Forms Data Format (FDF) documents.
class FDFParser extends COSParser {
  FDFParser(RandomAccessRead source)
      : _logger = Logger('pdfbox.FDFParser'),
        super(source);

  final Logger _logger;
  String? _documentVersion;

  String? get documentVersion => _documentVersion;

  FDFDocument parse({bool lenient = true}) {
    setLenient(lenient);
    final version = parseHeader('%FDF-', defaultVersion: '1.0');
    if (version == null) {
      const message = "Error: Header doesn't contain versioninfo";
      if (isLenient) {
        _logger.warning(message);
      } else {
        throw IOException(message);
      }
    } else {
      _documentVersion = version;
    }

    final COSDocument cosDocument = parseDocument();
    final COSDictionary? root = cosDocument.trailer.getCOSDictionary(COSName.root);
    if (root == null) {
      throw IOException('Missing root object specification in trailer.');
    }

    initialParseDone = true;
    return FDFDocument(cosDocument, source);
  }
}

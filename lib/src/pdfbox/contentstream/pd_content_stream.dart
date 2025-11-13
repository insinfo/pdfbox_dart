import '../../io/random_access_read.dart';

/// Minimal Dart port of PDFBox's PDContentStream interface.
abstract class PDContentStream {
  /// Returns a [RandomAccessRead] for stream parsing.
  RandomAccessRead getContentsForStreamParsing();
}

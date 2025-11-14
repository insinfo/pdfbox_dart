import '../../cos/cos_document.dart';
import '../../../io/random_access_read.dart';

/// Minimal FDF document wrapper exposing the parsed [COSDocument].
///
/// TODO: expand with the full FDF catalog API once `pdmodel/fdf` is ported.
class FDFDocument {
  FDFDocument(this._cosDocument, [this._source]);

  final COSDocument _cosDocument;
  final RandomAccessRead? _source;
  bool _closed = false;

  COSDocument get cosDocument => _cosDocument;

  bool get isClosed => _closed;

  void close() {
    if (_closed) {
      return;
    }
    _cosDocument.close();
    _source?.close();
    _closed = true;
  }
}

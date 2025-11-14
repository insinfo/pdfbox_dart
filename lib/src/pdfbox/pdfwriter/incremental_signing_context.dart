import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../io/range_filtered_random_access_read.dart';
import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../../io/random_access_write.dart';
import '../../io/sequence_random_access_read.dart';
import '../../pdfbox/cos/cos_array.dart';

/// Carries the incremental update bytes and offsets required to perform an
/// external signature update.
class IncrementalSigningContext {
  IncrementalSigningContext({
    required RandomAccessRead original,
    required this.target,
    required this.incrementalBytes,
    required this.signatureOffsetInIncrement,
    required this.signatureLength,
    required this.byteRangeArray,
    required this.incrementalRanges,
    required this.totalDocumentLength,
  }) : _original = original;

  final RandomAccessRead _original;
  final RandomAccessWrite target;
  final Uint8List incrementalBytes;
  final int signatureOffsetInIncrement;
  final int signatureLength;
  final COSArray byteRangeArray;
  final List<int> incrementalRanges;
  final int totalDocumentLength;

  bool _signatureApplied = false;
  List<int>? _byteRangeValues;

  set byteRangeValues(List<int> values) => _byteRangeValues = List<int>.from(values);

  /// Returns a [RandomAccessRead] containing the exact bytes that must be signed.
  RandomAccessRead openContentToSign() {
    final originalView = _createOriginalView();
    final filteredIncrement = RangeFilteredRandomAccessRead(incrementalBytes, incrementalRanges);
    return SequenceRandomAccessRead(<RandomAccessRead>[originalView, filteredIncrement]);
  }

  /// Writes the externally produced CMS signature into the incremental update
  /// and flushes the combined original + incremental data to [target].
  Future<void> applySignature(Uint8List cmsSignature) async {
    if (_signatureApplied) {
      throw StateError('Signature already applied');
    }
    final available = signatureLength - 2; // exclude angle brackets
    final hex = _toHex(cmsSignature);
    if (hex.length > available) {
      throw StateError(
          'Signature too large for reserved space: ${hex.length} > $available bytes');
    }

    final encoded = latin1.encode(hex);
    final contentsOffset = signatureOffsetInIncrement + 1;
    incrementalBytes.setRange(contentsOffset, contentsOffset + encoded.length, encoded);

    // copy original bytes
    _original.seek(0);
    final buffer = Uint8List(8192);
    var remaining = _original.length;
    target.clear();
    while (remaining > 0) {
      final read = _original.readBuffer(buffer, 0, remaining > buffer.length ? buffer.length : remaining);
      if (read <= 0) {
        break;
      }
      target.writeBytes(buffer, 0, read);
      remaining -= read;
    }
    if (incrementalBytes.isNotEmpty) {
      target.writeBytes(incrementalBytes);
    }
    _signatureApplied = true;
  }

  RandomAccessRead _createOriginalView() {
    try {
      return _original.createView(0, _original.length);
    } on Exception {
      final clone = Uint8List(_original.length);
      final initialPos = _original.position;
      _original.seek(0);
      _original.readFully(clone);
      _original.seek(initialPos);
      return RandomAccessReadBuffer.fromBytes(clone);
    }
  }

  static String _toHex(Uint8List data) {
    final buffer = StringBuffer();
    for (final byte in data) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }

  List<int> get byteRangeValues => List<int>.from(_byteRangeValues ?? const <int>[]);
}
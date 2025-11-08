import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';

/// Parser for Adobe Type 1 PFB files.
class PfbParser {
  PfbParser(Uint8List bytes) {
    _parse(Uint8List.fromList(bytes));
  }

  static const int _headerLength = 18;
  static const int _startMarker = 0x80;
  static const int _asciiMarker = 0x01;
  static const int _binaryMarker = 0x02;
  static const int _eofMarker = 0x03;

  static final Logger _log = Logger('fontbox.pfb.PfbParser');

  final List<int> _lengths = List<int>.filled(3, 0);
  late Uint8List _pfbData;

  /// Returns the concatenated PFB data.
  Uint8List get data => Uint8List.fromList(_pfbData);

  /// Returns the segment length metadata (ASCII, binary, trailing ASCII).
  List<int> get lengths => List<int>.unmodifiable(_lengths);

  /// Returns the size of the parsed data.
  int get size => _pfbData.length;

  /// Returns the ASCII segment of the font program.
  Uint8List get segment1 => Uint8List.fromList(_pfbData.sublist(0, _lengths[0]));

  /// Returns the binary segment of the font program.
  Uint8List get segment2 => Uint8List.fromList(
        _pfbData.sublist(_lengths[0], _lengths[0] + _lengths[1]),
      );

  void _parse(Uint8List bytes) {
    if (bytes.length < _headerLength) {
      throw IOException('PFB header missing');
    }

    final types = <int>[];
    final segments = <Uint8List>[];

    var index = 0;
    var totalLength = 0;

    while (index < bytes.length) {
      final marker = bytes[index++];
      if (marker != _startMarker) {
        if (totalLength > 0 && marker == 0) {
          break;
        }
        throw IOException('Start marker missing');
      }

      if (index >= bytes.length) {
        throw IOException('Unexpected EOF after start marker');
      }

      final recordType = bytes[index++];
      if (recordType == _eofMarker) {
        break;
      }
      if (recordType != _asciiMarker && recordType != _binaryMarker) {
        throw IOException('Incorrect record type: $recordType');
      }

      if (index + 4 > bytes.length) {
        throw IOException('Unexpected EOF when reading PFB record length');
      }

      final size = _readInt32(bytes, index);
      index += 4;

      if (size < 0 || size > bytes.length) {
        throw IOException('record size $size would be larger than the input');
      }

      if (index + size > bytes.length) {
        throw IOException('EOF while reading PFB font');
      }

  final segment = Uint8List.fromList(bytes.sublist(index, index + size));
  segments.add(segment);
      types.add(recordType);
      index += size;
      totalLength += size;
    }

    if (segments.isEmpty) {
      throw IOException('No segments found in PFB data');
    }

    if (totalLength > bytes.length) {
      throw IOException('total record size $totalLength would be larger than the input');
    }

    var destination = 0;
    _pfbData = Uint8List(totalLength);
    Uint8List? cleartomarkSegment;

    for (var i = 0; i < segments.length; i++) {
      if (types[i] != _asciiMarker) {
        continue;
      }
      final segment = segments[i];
      final isLast = i == segments.length - 1;
    if (isLast && segment.length < 600 &&
      ascii.decode(segment, allowInvalid: true).contains('cleartomark')) {
        cleartomarkSegment = segment;
        continue;
      }
      _pfbData.setRange(destination, destination + segment.length, segment);
      destination += segment.length;
    }
    _lengths[0] = destination;

    for (var i = 0; i < segments.length; i++) {
      if (types[i] != _binaryMarker) {
        continue;
      }
      final segment = segments[i];
      _pfbData.setRange(destination, destination + segment.length, segment);
      destination += segment.length;
    }
    _lengths[1] = destination - _lengths[0];

    if (cleartomarkSegment != null) {
      _pfbData.setRange(
        destination,
        destination + cleartomarkSegment.length,
        cleartomarkSegment,
      );
      destination += cleartomarkSegment.length;
      _lengths[2] = cleartomarkSegment.length;
    }

    if (destination != totalLength) {
      _log.fine(
        'Trimmed PFB data length from $totalLength to $destination due to filtered segments.',
      );
      _pfbData = Uint8List.fromList(_pfbData.sublist(0, destination));
    }
  }

  int _readInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
}

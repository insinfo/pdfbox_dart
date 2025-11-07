import '../../io/ttf_data_stream.dart';
import 'glyf_descript.dart';

/// Glyph description for simple outlines comprised exclusively of straight and quadratic segments.
class GlyfSimpleDescript extends GlyfDescript {
  /// Creates an empty description used for glyph records without contours.
  GlyfSimpleDescript.empty()
      : _endPtsOfContours = <int>[],
        _flags = <int>[],
        _xCoordinates = <int>[],
        _yCoordinates = <int>[],
        _pointCount = 0,
        super(0);

  /// Parses a simple glyph from [data].
  GlyfSimpleDescript(int numberOfContours, TtfDataStream data, int initialX)
      : _endPtsOfContours = <int>[],
        _flags = <int>[],
        _xCoordinates = <int>[],
        _yCoordinates = <int>[],
        _pointCount = 0,
        super(numberOfContours) {
    _initialise(numberOfContours, data, initialX);
  }

  final List<int> _endPtsOfContours;
  final List<int> _flags;
  final List<int> _xCoordinates;
  final List<int> _yCoordinates;
  int _pointCount;

  void _initialise(int numberOfContours, TtfDataStream data, int initialX) {
    if (numberOfContours <= 0) {
      return;
    }

    final endPts = data.readUnsignedShortArray(numberOfContours);
    if (endPts.isEmpty) {
      return;
    }

    final lastEndPt = endPts.last;
    if (numberOfContours == 1 && lastEndPt == 0xffff) {
      // PDFBOX-2939: treat malformed glyphs as empty.
      return;
    }

    _endPtsOfContours.addAll(endPts);
    _pointCount = lastEndPt + 1;

    _flags.addAll(List<int>.filled(_pointCount, 0));
    _xCoordinates.addAll(List<int>.filled(_pointCount, 0));
    _yCoordinates.addAll(List<int>.filled(_pointCount, 0));

    final instructionCount = data.readUnsignedShort();
    readInstructions(data, instructionCount);
    _readFlags(_pointCount, data);
    _readCoordinates(_pointCount, data, initialX);
  }

  void _readCoordinates(int count, TtfDataStream data, int initialX) {
    var x = initialX;
    var y = 0;
    for (var i = 0; i < count; i++) {
      final flag = _flags[i];
      if ((flag & GlyfDescript.X_DUAL) != 0) {
        if ((flag & GlyfDescript.X_SHORT_VECTOR) != 0) {
          x += data.readUnsignedByte();
        }
      } else {
        if ((flag & GlyfDescript.X_SHORT_VECTOR) != 0) {
          x -= data.readUnsignedByte();
        } else {
          x += data.readSignedShort();
        }
      }
      _xCoordinates[i] = x;
    }

    for (var i = 0; i < count; i++) {
      final flag = _flags[i];
      if ((flag & GlyfDescript.Y_DUAL) != 0) {
        if ((flag & GlyfDescript.Y_SHORT_VECTOR) != 0) {
          y += data.readUnsignedByte();
        }
      } else {
        if ((flag & GlyfDescript.Y_SHORT_VECTOR) != 0) {
          y -= data.readUnsignedByte();
        } else {
          y += data.readSignedShort();
        }
      }
      _yCoordinates[i] = y;
    }
  }

  void _readFlags(int count, TtfDataStream data) {
    var index = 0;
    while (index < count) {
      final flag = data.readUnsignedByte();
      _flags[index] = flag;
      if ((flag & GlyfDescript.REPEAT) != 0) {
        final repeats = data.readUnsignedByte();
        if (index + repeats >= count) {
          throw StateError(
              'repeat count ($repeats) exceeds remaining flag slots');
        }
        for (var i = 1; i <= repeats; i++) {
          _flags[index + i] = flag;
        }
        index += repeats;
      }
      index++;
    }
  }

  @override
  int getEndPtOfContours(int contourIndex) => _endPtsOfContours[contourIndex];

  @override
  int getFlags(int pointIndex) => _flags[pointIndex];

  @override
  @override
  int get pointCount => _pointCount;

  @override
  int getXCoordinate(int pointIndex) => _xCoordinates[pointIndex];

  @override
  int getYCoordinate(int pointIndex) => _yCoordinates[pointIndex];

  @override
  bool get isComposite => false;
}

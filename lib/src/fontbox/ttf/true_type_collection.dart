import '../../io/closeable.dart';
import '../../io/exceptions.dart';
import '../../io/io_utils.dart';
import '../../io/random_access_read.dart';
import '../io/random_access_read_data_stream.dart';
import '../io/ttc_data_stream.dart';
import '../io/ttf_data_stream.dart';
import 'font_headers.dart';
import 'otf_parser.dart';
import 'ttf_parser.dart';
import 'true_type_font.dart';

typedef TtfParserFactory = TtfParser Function(String tag);

/// Represents a TrueType Collection (TTC/OTC) file which bundles multiple fonts.
class TrueTypeCollection implements Closeable {
  TrueTypeCollection(TtfDataStream stream, {TtfParserFactory? parserFactory})
      : _stream = stream,
        _parserFactory = parserFactory ?? _defaultParserFactory {
    final header = _readHeader(stream);
    _version = header.version;
    _numFonts = header.numFonts;
    _fontOffsets = header.offsets;
  }

  factory TrueTypeCollection.fromRandomAccessRead(RandomAccessRead read,
      {bool closeAfterReading = true, TtfParserFactory? parserFactory}) {
    final dataStream = RandomAccessReadDataStream.fromRandomAccessRead(read);
    if (closeAfterReading) {
      IOUtils.closeQuietly(read);
    }
    return TrueTypeCollection(dataStream, parserFactory: parserFactory);
  }

  late final double _version;
  late final int _numFonts;
  late final List<int> _fontOffsets;
  final TtfDataStream _stream;
  final TtfParserFactory _parserFactory;
  bool _isClosed = false;

  double get version => _version;
  int get numFonts => _numFonts;

  @override
  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _stream.close();
  }

  /// Applies [processor] to every font contained in the collection.
  ///
  /// The callback receives an opened [TrueTypeFont] backed by the shared
  /// TTC data stream. Callers are responsible for closing the font when it is
  /// no longer required.
  void processAllFonts(TrueTypeFontProcessor processor) {
    for (var i = 0; i < _numFonts; i++) {
      final font = _getFontAtIndex(i);
      processor(font);
    }
  }

  /// Finds the first font whose PostScript name matches [name].
  TrueTypeFont? getFontByName(String name) {
    for (var i = 0; i < _numFonts; i++) {
      final font = _getFontAtIndex(i);
      final naming = font.getNamingTable();
      final postScriptName = naming?.getPostScriptName();
      if (postScriptName == name) {
        return font;
      }
      font.close();
    }
    return null;
  }

  /// Iterates over all fonts and emits only their header information.
  void processAllFontHeaders(TrueTypeFontHeadersProcessor processor) {
    for (var i = 0; i < _numFonts; i++) {
      final parser = _createParserForIndex(i);
      _stream.seek(_fontOffsets[i]);
      final headers =
          parser.parseTableHeadersFromDataStream(TtcDataStream(_stream));
      processor(headers);
    }
  }

  TrueTypeFont _getFontAtIndex(int index) {
    final parser = _createParserForIndex(index);
    _stream.seek(_fontOffsets[index]);
    final singleFontStream = TtcDataStream(_stream);
    return parser.parseDataStream(singleFontStream);
  }

  TtfParser _createParserForIndex(int index) {
    _stream.seek(_fontOffsets[index]);
    final tag = _stream.readTag();
    final parser = _parserFactory(tag);
    _stream.seek(_fontOffsets[index]);
    return parser;
  }

  _TtcHeader _readHeader(TtfDataStream stream) {
    final tag = stream.readTag();
    if (tag != 'ttcf') {
      throw IOException('Missing TTC header');
    }
    final version = stream.read32Fixed();
    final numFonts = stream.readUnsignedInt();
    if (numFonts <= 0 || numFonts > 1024) {
      throw IOException('Invalid number of fonts $numFonts');
    }
    final offsets =
        List<int>.generate(numFonts, (_) => stream.readUnsignedInt());
    if (version >= 2.0) {
      stream.readUnsignedInt();
      stream.readUnsignedInt();
      stream.readUnsignedInt();
    }
    return _TtcHeader(version, numFonts, offsets);
  }
}

/// Callback invoked for each font when iterating over the collection.
typedef TrueTypeFontProcessor = void Function(TrueTypeFont font);

/// Callback invoked when only font table headers are required.
typedef TrueTypeFontHeadersProcessor = void Function(FontHeaders headers);

class _TtcHeader {
  _TtcHeader(this.version, this.numFonts, this.offsets);

  final double version;
  final int numFonts;
  final List<int> offsets;
}

TtfParser _defaultParserFactory(String tag) =>
    tag == 'OTTO' ? OtfParser(isEmbedded: false) : TtfParser(isEmbedded: false);

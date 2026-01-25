

part of lzw_core;

/**
 * Base class for LZW converters.
 */
abstract class LzwConverter extends Converter<List<int>, List<int>> {

  List<int> convertSlice(List<int> chunk, int start, int end, bool isLast);

  List<int> flush();

  @override
  Sink<List<int>> startChunkedConversion(Sink<List<int>> sink) {
    final byteSink = sink is ByteConversionSink
        ? sink
        : new ByteConversionSink.from(sink);
    return new LzwSink(this, byteSink);
  }

  /**
   *  Override the base-classes bind, to provide a better type.
   */
  Stream<List<int>> bind(Stream<List<int>> stream) => super.bind(stream);
}

/**
 * LZW converter sink.
 */
class LzwSink extends ByteConversionSink {
  final LzwConverter _converter;

  final ChunkedConversionSink<List<int>> _sink;

  LzwSink(this._converter, this._sink);

  @override
  void add(List<int> chunk) {
    _sink.add(_converter.convert(chunk));
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    _sink.add(_converter.convertSlice(chunk, start, end, isLast));
    if (isLast) {
      close();
    }
  }

  @override
  void close() {
    _sink.add(_converter.flush());
    _sink.close();
  }
}

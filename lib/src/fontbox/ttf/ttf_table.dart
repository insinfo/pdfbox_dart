import '../io/ttf_data_stream.dart';
import 'font_headers.dart';

/// Base representation of a TrueType/OpenType table directory entry.
class TtfTable {
  String? _tag;
  int _checkSum = 0;
  int _offset = 0;
  int _length = 0;
  bool _initialized = false;

  int get checkSum => _checkSum;
  void setCheckSum(int value) => _checkSum = value;

  int get length => _length;
  void setLength(int value) => _length = value;

  int get offset => _offset;
  void setOffset(int value) => _offset = value;

  String? get tag => _tag;
  void setTag(String? value) => _tag = value;

  bool get initialized => _initialized;
  void setInitialized(bool value) => _initialized = value;

  void read(dynamic ttf, TtfDataStream data) {}

  void readHeaders(dynamic ttf, TtfDataStream data, FontHeaders outHeaders) {}
}

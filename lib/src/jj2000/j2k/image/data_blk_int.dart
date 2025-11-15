import 'data_blk.dart';

/// Integer implementation of [DataBlk].
class DataBlkInt extends DataBlk {
  List<int>? data;

  DataBlkInt();

  DataBlkInt.withGeometry(int ulx, int uly, int width, int height) {
    this.ulx = ulx;
    this.uly = uly;
    w = width;
    h = height;
    offset = 0;
    scanw = width;
    data = List<int>.filled(width * height, 0, growable: false);
  }

  DataBlkInt.copy(DataBlkInt source) {
    ulx = source.ulx;
    uly = source.uly;
    w = source.w;
    h = source.h;
    offset = 0;
    scanw = w;
    final src = source.data;
    if (src != null) {
      data = List<int>.filled(w * h, 0, growable: false);
      for (var row = 0; row < h; row++) {
        final destBase = row * scanw;
        final srcBase = row * source.scanw;
        for (var col = 0; col < w; col++) {
          data![destBase + col] = src[srcBase + col];
        }
      }
    }
  }

  @override
  int getDataType() => DataBlk.typeInt;

  @override
  Object? getData() => data;

  List<int>? getDataInt() => data;

  @override
  void setData(Object? value) {
    data = value as List<int>?;
  }

  void setDataInt(List<int>? value) {
    data = value;
  }

  @override
  String toString() {
    final base = super.toString();
    final length = data?.length;
    return length == null ? base : '$base,data=$length bytes';
  }
}

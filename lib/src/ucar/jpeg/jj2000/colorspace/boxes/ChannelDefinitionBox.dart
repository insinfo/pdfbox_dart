import 'dart:typed_data';
import '../../j2k/io/RandomAccessIO.dart';
import '../../icc/IccProfile.dart';
import 'Jp2Box.dart';

class ChannelDefinitionBox extends JP2Box {
  static int type = 0x63646566; // 'cdef'

  int ndefs = 0;
  Map<int, List<int>> definitions = {};

  ChannelDefinitionBox(RandomAccessIO in_io, int boxStart)
      : super(in_io, boxStart) {
    readBox();
  }

  void readBox() {
    Uint8List bfr = Uint8List(8);

    in_io!.seek(dataStart);
    in_io!.readFully(bfr, 0, 2);
    ndefs = ICCProfile.getShort(bfr, 0) & 0x0000ffff;

    int offset = dataStart + 2;
    in_io!.seek(offset);
    for (int i = 0; i < ndefs; ++i) {
      in_io!.readFully(bfr, 0, 6);
      // int channel = ICCProfile.getShort(bfr, 0); // Unused
      List<int> channel_def = List.filled(3, 0);
      channel_def[0] = _getCn(bfr);
      channel_def[1] = _getTyp(bfr);
      channel_def[2] = _getAsoc(bfr);
      definitions[channel_def[0]] = channel_def;
    }
  }

  int getNDefs() {
    return ndefs;
  }

  int getCn(int asoc) {
    for (var key in definitions.keys) {
      List<int> bfr = definitions[key]!;
      if (asoc == _getAsocFromIntArray(bfr)) return _getCnFromIntArray(bfr);
    }
    return asoc;
  }

  int getTyp(int channel) {
    List<int>? bfr = definitions[channel];
    if (bfr == null) return 0; // Or throw exception?
    return _getTypFromIntArray(bfr);
  }

  int getAsoc(int channel) {
    List<int>? bfr = definitions[channel];
    if (bfr == null) return 0; // Or throw exception?
    return _getAsocFromIntArray(bfr);
  }

  @override
  String toString() {
    StringBuffer rep = StringBuffer("[ChannelDefinitionBox ");
    rep.write(JP2Box.eol);
    rep.write("  ");
    rep.write("ndefs= $ndefs");

    for (var key in definitions.keys) {
      List<int> bfr = definitions[key]!;
      rep.write(JP2Box.eol);
      rep.write("  ");
      rep.write("Cn= ${_getCnFromIntArray(bfr)}, ");
      rep.write("Typ= ${_getTypFromIntArray(bfr)}, ");
      rep.write("Asoc= ${_getAsocFromIntArray(bfr)}");
    }

    rep.write("]");
    return rep.toString();
  }

  int _getCn(Uint8List bfr) {
    return ICCProfile.getShort(bfr, 0);
  }

  int _getTyp(Uint8List bfr) {
    return ICCProfile.getShort(bfr, 2);
  }

  int _getAsoc(Uint8List bfr) {
    return ICCProfile.getShort(bfr, 4);
  }

  int _getCnFromIntArray(List<int> bfr) {
    return bfr[0];
  }

  int _getTypFromIntArray(List<int> bfr) {
    return bfr[1];
  }

  int _getAsocFromIntArray(List<int> bfr) {
    return bfr[2];
  }
}


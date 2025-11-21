import 'dart:typed_data';
import '../../entropy/encoder/coded_cblk_data_src_enc.dart';
import '../../encoder/encoder_specs.dart';
import '../../image/coord.dart';
import '../../util/parameter_list.dart';
import '../../codestream/prec_info.dart';
import '../../entropy/encoder/cblk_rate_dist_stats.dart';
import 'bit_output_buffer.dart';

class PktEncoder {
  PktEncoder(CodedCBlkDataSrcEnc src, EncoderSpecs encSpec, List<List<List<Coord?>>>? numPrec, ParameterList pl);

  BitOutputBuffer encodePacket(int lay, int c, int r, int t, List<List<CBlkRateDistStats>> cblks, List<List<int>> truncIdxs, BitOutputBuffer? hBuff, Uint8List? bBuff, int p) {
    // TODO: implement encodePacket
    return BitOutputBuffer();
  }

  bool isPacketWritable() {
    // TODO: implement isPacketWritable
    return false;
  }

  Uint8List getLastBodyBuf() {
    // TODO: implement getLastBodyBuf
    return Uint8List(0);
  }

  int getLastBodyLen() {
    // TODO: implement getLastBodyLen
    return 0;
  }

  bool isROIinPkt() {
    // TODO: implement isROIinPkt
    return false;
  }

  int getROILen() {
    // TODO: implement getROILen
    return 0;
  }

  void reset() {
    // TODO: implement reset
  }

  void save() {
    // TODO: implement save
  }

  void restore() {
    // TODO: implement restore
  }

  PrecInfo getPrecInfo(int t, int c, int r, int p) {
    // TODO: implement getPrecInfo
    return PrecInfo(0, 0, 0, 0, 0, 0, 0, 0, 0);
  }
}

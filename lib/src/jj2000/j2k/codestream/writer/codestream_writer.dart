import 'dart:typed_data';
import 'header_encoder.dart';

/// Placeholder for CodestreamWriter
abstract class CodestreamWriter {
  int writePacketHead(Uint8List head, int hlen, bool sim, bool sop, bool eph);
  int writePacketBody(Uint8List body, int blen, bool sim, bool roiInPkt, int roiLen);
  void commitBitstreamHeader(HeaderEncoder he);
  int getMaxAvailableBytes();
  int getLength();
  int getOff();
  void close();
}

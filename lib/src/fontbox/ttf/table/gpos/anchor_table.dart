import '../../../io/ttf_data_stream.dart';

/// Represents an anchor point used in mark attachment and cursive positioning.
class AnchorTable {
  AnchorTable({
    required this.xCoordinate,
    required this.yCoordinate,
    this.anchorPoint,
    this.xDeviceTableOffset,
    this.yDeviceTableOffset,
  });

  final int xCoordinate;
  final int yCoordinate;
  final int? anchorPoint;
  final int? xDeviceTableOffset;
  final int? yDeviceTableOffset;

  bool get hasAnchorPoint => anchorPoint != null;
  bool get hasDeviceTables =>
      (xDeviceTableOffset != null && xDeviceTableOffset != 0) ||
      (yDeviceTableOffset != null && yDeviceTableOffset != 0);

  static AnchorTable read(TtfDataStream data, int offset) {
    final saved = data.currentPosition;
    data.seek(offset);
    final format = data.readUnsignedShort();
    switch (format) {
      case 1:
        {
          final x = data.readSignedShort();
          final y = data.readSignedShort();
          data.seek(saved);
          return AnchorTable(xCoordinate: x, yCoordinate: y);
        }
      case 2:
        {
          final x = data.readSignedShort();
          final y = data.readSignedShort();
          final anchorPoint = data.readUnsignedShort();
          data.seek(saved);
          return AnchorTable(
            xCoordinate: x,
            yCoordinate: y,
            anchorPoint: anchorPoint,
          );
        }
      case 3:
        {
          final x = data.readSignedShort();
          final y = data.readSignedShort();
          final xDevice = data.readUnsignedShort();
          final yDevice = data.readUnsignedShort();
          data.seek(saved);
          return AnchorTable(
            xCoordinate: x,
            yCoordinate: y,
            xDeviceTableOffset: xDevice == 0 ? null : xDevice,
            yDeviceTableOffset: yDevice == 0 ? null : yDevice,
          );
        }
      default:
        data.seek(saved);
        return AnchorTable(xCoordinate: 0, yCoordinate: 0);
    }
  }
}

import '../../../io/ttf_data_stream.dart';

/// Represents positioning adjustments for a single glyph.
class ValueRecord {
  ValueRecord({
    this.xPlacement = 0,
    this.yPlacement = 0,
    this.xAdvance = 0,
    this.yAdvance = 0,
  });

  factory ValueRecord.read(TtfDataStream data, int valueFormat) {
    var xPlacement = 0;
    var yPlacement = 0;
    var xAdvance = 0;
    var yAdvance = 0;

    if ((valueFormat & 0x0001) != 0) {
      xPlacement = data.readSignedShort();
    }
    if ((valueFormat & 0x0002) != 0) {
      yPlacement = data.readSignedShort();
    }
    if ((valueFormat & 0x0004) != 0) {
      xAdvance = data.readSignedShort();
    }
    if ((valueFormat & 0x0008) != 0) {
      yAdvance = data.readSignedShort();
    }

    // Skip device tables / variation indices for now.
    var remainingFormat = valueFormat & ~0x000F;
    while (remainingFormat != 0) {
      final lowestBit = remainingFormat & -remainingFormat;
      remainingFormat &= remainingFormat - 1;
      data.readUnsignedShort();
      if (lowestBit >= 0x0100) {
        // Variation index is unsigned short per spec.
        continue;
      }
    }

    return ValueRecord(
      xPlacement: xPlacement,
      yPlacement: yPlacement,
      xAdvance: xAdvance,
      yAdvance: yAdvance,
    );
  }

  final int xPlacement;
  final int yPlacement;
  final int xAdvance;
  final int yAdvance;

  bool get isZero =>
      xPlacement == 0 && yPlacement == 0 && xAdvance == 0 && yAdvance == 0;

  ValueRecord operator +(ValueRecord other) => ValueRecord(
        xPlacement: xPlacement + other.xPlacement,
        yPlacement: yPlacement + other.yPlacement,
        xAdvance: xAdvance + other.xAdvance,
        yAdvance: yAdvance + other.yAdvance,
      );
}

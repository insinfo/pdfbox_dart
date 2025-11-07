import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// TrueType 'maxp' table summarizing maximum profile values used by glyph processing.
class MaximumProfileTable extends TtfTable {
  static const String tableTag = 'maxp';

  double version = 0;
  int numGlyphs = 0;
  int maxPoints = 0;
  int maxContours = 0;
  int maxCompositePoints = 0;
  int maxCompositeContours = 0;
  int maxZones = 0;
  int maxTwilightPoints = 0;
  int maxStorage = 0;
  int maxFunctionDefs = 0;
  int maxInstructionDefs = 0;
  int maxStackElements = 0;
  int maxSizeOfInstructions = 0;
  int maxComponentElements = 0;
  int maxComponentDepth = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    version = data.read32Fixed();
    numGlyphs = data.readUnsignedShort();
    if (version >= 1.0) {
      maxPoints = data.readUnsignedShort();
      maxContours = data.readUnsignedShort();
      maxCompositePoints = data.readUnsignedShort();
      maxCompositeContours = data.readUnsignedShort();
      maxZones = data.readUnsignedShort();
      maxTwilightPoints = data.readUnsignedShort();
      maxStorage = data.readUnsignedShort();
      maxFunctionDefs = data.readUnsignedShort();
      maxInstructionDefs = data.readUnsignedShort();
      maxStackElements = data.readUnsignedShort();
      maxSizeOfInstructions = data.readUnsignedShort();
      maxComponentElements = data.readUnsignedShort();
      maxComponentDepth = data.readUnsignedShort();
    }
    setInitialized(true);
  }
}

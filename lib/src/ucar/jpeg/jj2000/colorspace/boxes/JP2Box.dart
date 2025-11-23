import 'dart:typed_data';
import '../../j2k/io/RandomAccessIO.dart';
import '../../j2k/fileformat/FileFormatBoxes.dart';
import '../ColorSpaceException.dart';
import '../../icc/IccProfile.dart';

abstract class JP2Box {
  /** Platform dependant line terminator */
  static const String eol = '\n'; // System.getProperty ("line.separator");
  /** Box type                           */
  static int type = 0;

  /** Return a String representation of the Box type. */
  static String getTypeStringFromType(int t) {
    return BoxType.get(t);
  }

  /** Length of the box.             */
  int length = 0;
  /** input file                     */
  RandomAccessIO? in_io;
  /** offset to start of box         */
  int boxStart = 0;
  /** offset to end of box           */
  int boxEnd = 0;
  /** offset to start of data in box */
  int dataStart = 0;

  JP2Box([RandomAccessIO? in_io, int? boxStart]) {
    if (in_io != null && boxStart != null) {
      Uint8List boxHeader = Uint8List(16);

      this.in_io = in_io;
      this.boxStart = boxStart;

      this.in_io!.seek(this.boxStart);
      this.in_io!.readFully(boxHeader, 0, 8);

      this.dataStart = boxStart + 8;
      this.length = ICCProfile.getInt(boxHeader, 0);
      this.boxEnd = boxStart + length;
      if (length == 1) {
        throw ColorSpaceException("extended length boxes not supported");
      }
    }
  }

  /** Return the box type as a String. */
  String getTypeString() {
    return BoxType.get(JP2Box.type);
  }
}

/** JP2 Box structure analysis help */
class BoxType {
  static final Map<int, String> map = {};

  static void _init() {
    put(FileFormatBoxes.bitsPerComponentBox, "BITS_PER_COMPONENT_BOX");
    put(FileFormatBoxes.captureResolutionBox, "CAPTURE_RESOLUTION_BOX");
    put(FileFormatBoxes.channelDefinitionBox, "CHANNEL_DEFINITION_BOX");
    put(FileFormatBoxes.colourSpecificationBox, "COLOUR_SPECIFICATION_BOX");
    put(FileFormatBoxes.componentMappingBox, "COMPONENT_MAPPING_BOX");
    put(FileFormatBoxes.contiguousCodestreamBox, "CONTIGUOUS_CODESTREAM_BOX");
    put(FileFormatBoxes.defaultDisplayResolutionBox,
        "DEFAULT_DISPLAY_RESOLUTION_BOX");
    put(FileFormatBoxes.fileTypeBox, "FILE_TYPE_BOX");
    put(FileFormatBoxes.imageHeaderBox, "IMAGE_HEADER_BOX");
    put(FileFormatBoxes.intellectualPropertyBox, "INTELLECTUAL_PROPERTY_BOX");
    put(FileFormatBoxes.jp2HeaderBox, "JP2_HEADER_BOX");
    put(FileFormatBoxes.jp2SignatureBox, "JP2_SIGNATURE_BOX");
    put(FileFormatBoxes.paletteBox, "PALETTE_BOX");
    put(FileFormatBoxes.resolutionBox, "RESOLUTION_BOX");
    put(FileFormatBoxes.urlBox, "URL_BOX");
    put(FileFormatBoxes.uuidBox, "UUID_BOX");
    put(FileFormatBoxes.uuidInfoBox, "UUID_INFO_BOX");
    put(FileFormatBoxes.uuidListBox, "UUID_LIST_BOX");
    put(FileFormatBoxes.xmlBox, "XML_BOX");
  }

  static void put(int type, String desc) {
    map[type] = desc;
  }

  static String get(int type) {
    if (map.isEmpty) _init();
    return map[type] ?? "Unknown Box Type";
  }
}


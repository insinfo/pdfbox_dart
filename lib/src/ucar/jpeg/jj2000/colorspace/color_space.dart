import '../j2k/util/parameter_list.dart';
import '../j2k/codestream/reader/header_decoder.dart';
import '../j2k/io/random_access_io.dart';
import '../j2k/fileformat/file_format_boxes.dart';
import '../icc/icc_profile.dart';
import 'color_space_exception.dart';
import 'boxes/palette_box.dart';
import 'boxes/component_mapping_box.dart';
import 'boxes/color_specification_box.dart';
import 'boxes/channel_definition_box.dart';
import 'boxes/image_header_box.dart';

class ColorSpace {
  static const String eol = '\n';

  // Renamed for convenience:
  static const int GRAY = 0;
  static const int RED = 1;
  static const int GREEN = 2;
  static const int BLUE = 3;

  /** Parameter Specs */
  ParameterList? pl;

  /** Parameter Specs */
  HeaderDecoder? hd;

  /* Image box structure as pertains to colorspacees. */
  PaletteBox? pbox;
  ComponentMappingBox? cmbox;
  ColorSpecificationBox? csbox;
  ChannelDefinitionBox? cdbox;
  ImageHeaderBox? ihbox;
  List<ColorSpecificationBox>? csboxes;

  /** Input image */
  RandomAccessIO? in_io;

  /**
     * Retrieve the ICC profile from the images as
     * a byte array.
     * @return the ICC Profile as a byte [].
     */
  List<int>? getICCProfile() {
    return csbox?.getICCProfile();
  }

  /** Indent a String that contains newlines. */
  static String indent(String ident, String instr) {
    StringBuffer tgt = StringBuffer(instr);
    // char eolChar = eol.charAt(0); // Assuming \n
    String eolChar = '\n';
    int i = tgt.length;
    while (--i > 0) {
      if (tgt.toString()[i] == eolChar) {
        // This is inefficient in Dart strings, but okay for now
        String s = tgt.toString();
        tgt = StringBuffer(s.substring(0, i + 1) + ident + s.substring(i + 1));
      }
    }
    return ident + tgt.toString();
  }

  ColorSpace(this.in_io, this.hd, this.pl) {
    getBoxes();
  }

  /**
     * Retrieve the various boxes from the JP2 file.
     * @exception ColorSpaceException, IOException
     */
  void getBoxes() {
    int type;
    int len = 0;
    int boxStart = 0;
    List<int> boxHeader = List.filled(16, 0);
    int i = 0;

    // Search the toplevel boxes for the header box
    while (true) {
      in_io!.seek(boxStart);
      in_io!.readFully(boxHeader, 0, 16);
      len = ICCProfile.getInt(boxHeader as dynamic, 0); // Cast to dynamic or Uint8List
      if (len == 1)
        len = ICCProfile.getLong(boxHeader as dynamic, 8); // Extended length
      type = ICCProfile.getInt(boxHeader as dynamic, 4);

      // Verify the contents of the file so far.
      if (i == 0 && type != FileFormatBoxes.jp2SignatureBox) {
        throw ColorSpaceException("first box in image not signature");
      } else if (i == 1 && type != FileFormatBoxes.fileTypeBox) {
        throw ColorSpaceException("second box in image not file");
      } else if (type == FileFormatBoxes.contiguousCodestreamBox) {
        throw ColorSpaceException("header box not found in image");
      } else if (type == FileFormatBoxes.jp2HeaderBox) {
        break;
      }

      // Progress to the next box.
      ++i;
      boxStart += len;
    }

    // boxStart indexes the start of the JP2_HEADER_BOX,
    // make headerBoxEnd index the end of the box.
    int headerBoxEnd = boxStart + len;

    if (len == 1) boxStart += 8; // Extended length header

    for (boxStart += 8; boxStart < headerBoxEnd; boxStart += len) {
      in_io!.seek(boxStart);
      in_io!.readFully(boxHeader, 0, 16);
      len = ICCProfile.getInt(boxHeader as dynamic, 0);
      if (len == 1)
        throw ColorSpaceException("Extended length boxes not supported");
      type = ICCProfile.getInt(boxHeader as dynamic, 4);

      switch (type) {
        case FileFormatBoxes.imageHeaderBox:
          ihbox = ImageHeaderBox(in_io!, boxStart);
          break;
        case FileFormatBoxes.colourSpecificationBox:
          csbox = ColorSpecificationBox(in_io!, boxStart);
          if (csboxes == null) {
            csboxes = [];
          }
          csboxes!.add(csbox!);
          break;
        case FileFormatBoxes.channelDefinitionBox:
          cdbox = ChannelDefinitionBox(in_io!, boxStart);
          break;
        case FileFormatBoxes.componentMappingBox:
          cmbox = ComponentMappingBox(in_io!, boxStart);
          break;
        case FileFormatBoxes.paletteBox:
          pbox = PaletteBox(in_io!, boxStart);
          break;
        default:
          break;
      }
    }

    if (ihbox == null) throw ColorSpaceException("image header box not found");

    if ((pbox == null && cmbox != null) || (pbox != null && cmbox == null))
      throw ColorSpaceException(
          "palette box and component mapping box inconsistency");
  }

  /** Return the channel definition of the input component. */
  int getChannelDefinition(int c) {
    if (cdbox == null)
      return c;
    else
      return cdbox!.getCn(c + 1);
  }

  /** Return the colorspace method (Profiled, enumerated, or palettized). */
  MethodEnum getMethod() {
    return csbox!.getMethod();
  }

  /** Return the colorspace (sYCC, sRGB, sGreyScale). */
  CSEnum getColorSpace() {
    return csbox!.getColorSpace();
  }

  /** Return number of channels in the palette. */
  PaletteBox? getPaletteBox() {
    return pbox;
  }

  List<ColorSpecificationBox> getColorSpecificationBoxes() {
    return csboxes == null ? [] : csboxes!;
  }

  /** Return number of channels in the palette. */
  int getPaletteChannels() {
    return pbox == null ? 0 : pbox!.getNumColumns();
  }

  /** Return bitdepth of the palette entries. */
  int getPaletteChannelBits(int c) {
    return pbox == null ? 0 : pbox!.getBitDepth(c);
  }

  /**
     * Return a palettized sample
     *   @param channel requested 
     *   @param index of entry
     * @return palettized sample
     */
  int getPalettizedSample(int channel, int index) {
    return pbox == null ? 0 : pbox!.getEntry(channel, index);
  }

  /** Is palettized predicate. */
  bool isPalettized() {
    return pbox != null;
  }

  /** Signed output predicate. */
  bool isOutputSigned(int channel) {
    return (pbox != null)
        ? pbox!.isSigned(channel)
        : hd!.isOriginalSigned(channel);
  }

  @override
  String toString() {
    StringBuffer rep = StringBuffer("[ColorSpace is ");
    rep.write(csbox!.getMethodString());
    rep.write(isPalettized() ? "  and palettized " : " ");
    rep.write(getMethod() == ENUMERATED ? csbox!.getColorSpaceString() : "");
    if (ihbox != null) {
      rep.write(eol);
      rep.write(indent("    ", ihbox.toString()));
    }
    if (cdbox != null) {
      rep.write(eol);
      rep.write(indent("    ", cdbox.toString()));
    }
    if (csbox != null) {
      rep.write(eol);
      rep.write(indent("    ", csbox.toString()));
    }
    if (pbox != null) {
      rep.write(eol);
      rep.write(indent("    ", pbox.toString()));
    }
    if (cmbox != null) {
      rep.write(eol);
      rep.write(indent("    ", cmbox.toString()));
    }
    rep.write("]");
    return rep.toString();
  }

  /**
     * Are profiling diagnostics turned on
     * @return yes or no
     */
  bool debugging() {
    return pl!.getParameter("colorspace_debug") != null &&
        pl!.getParameter("colorspace_debug")!.toLowerCase() == "on";
  }

  /* Enumeration Class */
  /** method enumeration */
  static final MethodEnum ICC_PROFILED = MethodEnum("profiled");
  /** method enumeration */
  static final MethodEnum ENUMERATED = MethodEnum("enumerated");

  /** colorspace enumeration */
  static final CSEnum sRGB = CSEnum("sRGB");
  /** colorspace enumeration */
  static final CSEnum GreyScale = CSEnum("GreyScale");
  /** colorspace enumeration */
  static final CSEnum sYCC = CSEnum("sYCC");
  /** colorspace enumeration */
  static final CSEnum Illegal = CSEnum("Illegal");
  /** colorspace enumeration */
  static final CSEnum Unknown = CSEnum("Unknown");
}

class Enumeration {
  final String value;
  const Enumeration(this.value);
  @override
  String toString() {
    return value;
  }
}

class MethodEnum extends Enumeration {
  const MethodEnum(String value) : super(value);
}

class CSEnum extends Enumeration {
  const CSEnum(String value) : super(value);
}

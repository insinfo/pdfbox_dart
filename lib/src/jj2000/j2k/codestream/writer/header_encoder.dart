import '../../image/img_data.dart';
import '../../util/parameter_list.dart';
import '../../encoder/encoder_specs.dart';
import 'codestream_writer.dart';

/// This class writes the main and tile-part headers.
///
/// <p>It is used by the CodestreamWriter to write the headers to the bit
/// stream.</p>
class HeaderEncoder {
  /// The source of image data
  ImgData src;

  /// The boolean flag that indicates if the main header has been written.
  bool mainHeaderWritten = false;

  /// The encoder specifications
  EncoderSpecs encSpec;

  /// The codestream writer
  CodestreamWriter bsWriter;

  /// The parameter list
  ParameterList pl;

  /// Initializes the header encoder.
  ///
  /// [src] The source of image data.
  ///
  /// [bsWriter] The codestream writer.
  ///
  /// [encSpec] The encoder specifications.
  ///
  /// [pl] The parameter list.
  HeaderEncoder(this.src, this.bsWriter, this.encSpec, this.pl);

  /// Resets the header encoder. This method should be called before starting
  /// to write a new tile.
  void reset() {
    // Implementation needed
  }

  /// Returns the length of the header.
  ///
  /// @return The length of the header.
  int getLength() {
    // Implementation needed
    return 0;
  }

  /// Encodes the tile-part header.
  ///
  /// [tileLen] The length of the tile-part.
  ///
  /// [tileIdx] The index of the tile.
  void encodeTilePartHeader(int tileLen, int tileIdx) {
    // Implementation needed
  }

  /// Encodes the main header.
  void encodeMainHeader() {
    // Implementation needed
  }
}


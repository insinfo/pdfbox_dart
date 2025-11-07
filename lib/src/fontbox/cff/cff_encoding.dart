import '../encoding/encoding.dart';
import 'cff_standard_string.dart';

/// Base class for CFF encodings.
abstract class CFFEncoding extends Encoding {
  CFFEncoding();

  /// Registers a custom mapping using the provided glyph name.
  void addCode(int code, int sid, String name) {
    addCharacterEncoding(code, name);
  }

  /// Registers a mapping using the standard SID lookup table.
  void addStandard(int code, int sid) {
    addCharacterEncoding(code, CFFStandardString.getName(sid));
  }
}

import '../../../fontbox/cmap/cmap.dart';

/// Minimal contract required by descendant CID fonts to interact with their owner.
abstract class PDCIDFontParent {
  /// PostScript base font name.
  String? get name;

  /// Resolves a character code to the corresponding CID.
  int codeToCid(int code);

  /// Returns the optional UCS-2 CMap when available.
  CMap? get cMapUcs2;
}

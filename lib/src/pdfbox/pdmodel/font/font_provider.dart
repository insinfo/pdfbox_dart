import 'font_info.dart';

/// Interface for runtime font discovery providers.
abstract class FontProvider {
  /// Returns debugging information emitted when no matching fonts are found.
  String? toDebugString();

  /// Enumerates every font known to this provider.
  List<FontInfo> getFontInfo();
}

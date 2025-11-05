import 'native_font_dir_finder.dart';

/// Discoverer for macOS font directories.
class MacFontDirFinder extends NativeFontDirFinder {
  @override
  Iterable<String?> getSearchableDirectories() {
    final userHome = userHomeDirectory();
    return <String?>[
      if (userHome != null) '$userHome/Library/Fonts',
      '/Library/Fonts',
      '/System/Library/Fonts',
      '/Network/Library/Fonts',
    ];
  }
}

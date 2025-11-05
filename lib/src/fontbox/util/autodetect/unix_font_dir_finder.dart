import 'native_font_dir_finder.dart';

/// Discoverer for Unix-style systems (Linux, BSD, etc.).
class UnixFontDirFinder extends NativeFontDirFinder {
  @override
  Iterable<String?> getSearchableDirectories() {
    final userHome = userHomeDirectory();
    return <String?>[
      if (userHome != null) '$userHome/.fonts',
      '/usr/local/fonts',
      '/usr/local/share/fonts',
      '/usr/share/fonts',
      '/usr/X11R6/lib/X11/fonts',
      '/usr/share/X11/fonts',
    ];
  }
}

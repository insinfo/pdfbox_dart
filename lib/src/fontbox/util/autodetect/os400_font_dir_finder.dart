import 'native_font_dir_finder.dart';

/// Discoverer for IBM OS/400 systems.
class OS400FontDirFinder extends NativeFontDirFinder {
  @override
  Iterable<String?> getSearchableDirectories() {
    final userHome = userHomeDirectory();
    return <String?>[
      if (userHome != null) '$userHome/.fonts',
      '/QIBM/ProdData/OS400/Fonts',
    ];
  }
}

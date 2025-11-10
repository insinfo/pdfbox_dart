import 'dart:io';

import 'package:logging/logging.dart';

import 'file_system_font_info.dart';
import 'font_cache.dart';
import 'font_format.dart';
import 'font_info.dart';
import 'font_provider.dart';

/// Discovers fonts by scanning directories on the local file system.
class FileSystemFontProvider extends FontProvider {
  FileSystemFontProvider({
    List<Directory>? searchPaths,
    FontCache? cache,
    Logger? logger,
  })  : _logger = logger ?? Logger('pdfbox.FileSystemFontProvider'),
        _cache = cache ?? FontCache() {
    _searchPaths = searchPaths ?? _defaultSearchPaths();
    _fontInfo = _collectFonts();
  }

  final Logger _logger;
  final FontCache _cache;
  late final List<Directory> _searchPaths;
  late final List<FileSystemFontInfo> _fontInfo;

  static List<Directory> _defaultSearchPaths() {
    final seen = <String>{};
    void addPath(String? rawPath) {
      if (rawPath == null || rawPath.isEmpty) {
        return;
      }
      final directory = Directory(rawPath).absolute;
      if (!directory.existsSync()) {
        return;
      }
      seen.add(directory.path);
    }

    final root = Directory.current;
    addPath(
        '${root.path}${Platform.pathSeparator}resources${Platform.pathSeparator}ttf');
    addPath(
        '${root.path}${Platform.pathSeparator}resources${Platform.pathSeparator}otf');

    if (Platform.isWindows) {
      final windowsDir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      addPath('$windowsDir${Platform.pathSeparator}Fonts');
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        addPath(
            '$localAppData${Platform.pathSeparator}Microsoft${Platform.pathSeparator}Windows${Platform.pathSeparator}Fonts');
      }
    } else if (Platform.isMacOS) {
      addPath('/System/Library/Fonts');
      addPath('/Library/Fonts');
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        addPath('$home/Library/Fonts');
      }
    } else {
      // Assume Unix-like (Linux, BSD, etc.)
      addPath('/usr/share/fonts');
      addPath('/usr/local/share/fonts');
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        addPath('$home/.fonts');
        addPath('$home/.local/share/fonts');
      }
    }

    final paths = <Directory>[];
    for (final path in seen) {
      final directory = Directory(path);
      if (directory.existsSync()) {
        paths.add(directory);
      }
    }
    return paths;
  }

  List<FileSystemFontInfo> _collectFonts() {
    final fonts = <FileSystemFontInfo>[];
    final seenPaths = <String>{};
    for (final directory in _searchPaths) {
      if (!directory.existsSync()) {
        continue;
      }
      try {
        for (final entity
            in directory.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) {
            continue;
          }
          final format = _detectFormat(entity);
          if (format == null) {
            continue;
          }
          final canonicalPath = File(entity.path).absolute.path;
          if (!seenPaths.add(canonicalPath)) {
            continue;
          }
          try {
            fonts.add(FileSystemFontInfo(
              path: canonicalPath,
              format: format,
              cache: _cache,
              logger: _logger,
            ));
          } catch (error, stackTrace) {
            _logger.warning(
                'Failed to register font at $canonicalPath', error, stackTrace);
          }
        }
      } on FileSystemException catch (error, stackTrace) {
        _logger.fine(
            'Failed to scan fonts in ${directory.path}', error, stackTrace);
      }
    }
    return fonts;
  }

  FontFormat? _detectFormat(File file) {
    final name = file.path.toLowerCase();
    if (name.endsWith('.ttf') || name.endsWith('.ttc')) {
      return FontFormat.ttf;
    }
    if (name.endsWith('.otf')) {
      return FontFormat.otf;
    }
    if (name.endsWith('.pfb')) {
      return FontFormat.pfb;
    }
    return null;
  }

  @override
  String? toDebugString() {
    final buffer = StringBuffer()..writeln('FileSystemFontProvider scanned:');
    for (final directory in _searchPaths) {
      buffer.writeln(' - ${directory.path}');
    }
    buffer.writeln('Discovered ${_fontInfo.length} fonts');
    return buffer.toString();
  }

  @override
  List<FontInfo> getFontInfo() => List<FontInfo>.unmodifiable(_fontInfo);

  /// Exposes the internally shared cache so external callers can reuse it.
  FontCache get cache => _cache;
}

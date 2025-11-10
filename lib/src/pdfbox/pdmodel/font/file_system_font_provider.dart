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
    final root = Directory.current;
    return <Directory>[
      Directory('${root.path}${Platform.pathSeparator}resources${Platform.pathSeparator}ttf'),
      Directory('${root.path}${Platform.pathSeparator}resources${Platform.pathSeparator}otf'),
    ];
  }

  List<FileSystemFontInfo> _collectFonts() {
    final fonts = <FileSystemFontInfo>[];
    for (final directory in _searchPaths) {
      if (!directory.existsSync()) {
        continue;
      }
      for (final entity in directory.listSync(recursive: false)) {
        if (entity is! File) {
          continue;
        }
        final format = _detectFormat(entity);
        if (format == null) {
          continue;
        }
        try {
          fonts.add(FileSystemFontInfo(
            path: entity.path,
            format: format,
            cache: _cache,
            logger: _logger,
          ));
        } catch (error, stackTrace) {
          _logger.warning('Failed to register font at ${entity.path}', error, stackTrace);
        }
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
    final buffer = StringBuffer()
      ..writeln('FileSystemFontProvider scanned:');
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

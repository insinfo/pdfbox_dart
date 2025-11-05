import 'dart:io';

import 'package:logging/logging.dart';

import 'font_dir_finder.dart';
import 'mac_font_dir_finder.dart';
import 'os400_font_dir_finder.dart';
import 'unix_font_dir_finder.dart';
import 'windows_font_dir_finder.dart';

final Logger _log = Logger('FontFileFinder');

/// Utility that enumerates installed font files on the host system.
class FontFileFinder {
  FontFileFinder({FontDirFinder? dirFinder}) : _fontDirFinder = dirFinder;

  FontDirFinder? _fontDirFinder;

  /// Finds font files by autodetecting platform-specific directories.
  List<Uri> find([String? directoryPath]) {
    if (directoryPath != null) {
      return _findInDirectoryPath(directoryPath);
    }

    final finder = _fontDirFinder ??= _determineDirFinder();
    final fontDirs = finder.find();
    final results = <Uri>[];
    for (final dir in fontDirs) {
      _walk(dir, results);
    }
    return results;
  }

  FontDirFinder _determineDirFinder() {
    final os = Platform.operatingSystem;
    if (os == 'windows') {
      return WindowsFontDirFinder();
    }
    if (os == 'macos') {
      return MacFontDirFinder();
    }
    final osVersion = Platform.operatingSystemVersion.toLowerCase();
    if (osVersion.contains('os/400')) {
      return OS400FontDirFinder();
    }
    return UnixFontDirFinder();
  }

  List<Uri> _findInDirectoryPath(String directoryPath) {
    final directory = Directory(directoryPath);
    final results = <Uri>[];
    if (directory.existsSync()) {
      _walk(directory, results);
    }
    return results;
  }

  void _walk(Directory directory, List<Uri> results) {
    try {
      final entities = directory.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is Directory) {
          if (_isHidden(entity)) {
            _log.fine('Skipping hidden font directory ${entity.path}');
            continue;
          }
          _walk(entity, results);
        } else if (entity is File) {
          _log.finer('Checking potential font file ${entity.path}');
          if (_isFontFile(entity)) {
            _log.fine('Detected font file ${entity.path}');
            results.add(entity.uri);
          }
        }
      }
    } on FileSystemException catch (err, stackTrace) {
      _log.fine('Ignoring ${directory.path} due to IO error', err, stackTrace);
    } on Exception catch (err, stackTrace) {
      _log.fine('Ignoring ${directory.path} due to unexpected error', err, stackTrace);
    }
  }

  bool _isHidden(Directory directory) {
    final name = _basename(directory.path);
    return name.startsWith('.');
  }

  bool _isFontFile(File file) {
    final name = _basename(file.path).toLowerCase();
    if (name.startsWith('fonts.')) {
      return false;
    }
    return name.endsWith('.ttf') ||
        name.endsWith('.otf') ||
        name.endsWith('.pfb') ||
        name.endsWith('.ttc');
  }

  String _basename(String path) {
    if (path.isEmpty) {
      return path;
    }
    final separatorPattern = RegExp(r'[\\/]');
    final segments = path.split(separatorPattern);
    for (var i = segments.length - 1; i >= 0; i--) {
      final segment = segments[i];
      if (segment.isNotEmpty) {
        return segment;
      }
    }
    return path;
  }
}

import 'dart:io';

import 'package:logging/logging.dart';

import 'font_dir_finder.dart';

final Logger _log = Logger('NativeFontDirFinder');

/// Base implementation for POSIX-like font directory discovery.
abstract class NativeFontDirFinder implements FontDirFinder {
  @override
  List<Directory> find() {
    final directories = <Directory>[];
    for (final location in getSearchableDirectories()) {
      if (location == null || location.isEmpty) {
        continue;
      }
      final directory = Directory(location);
      try {
        if (directory.existsSync()) {
          // statSync acts as a light permission probe similar to File.canRead in Java.
          directory.statSync();
          directories.add(directory);
        }
      } on FileSystemException catch (err, stackTrace) {
        _log.fine('Ignoring inaccessible font directory $location', err, stackTrace);
      } on Exception catch (err, stackTrace) {
        _log.fine('Ignoring font directory $location due to error', err, stackTrace);
      }
    }
    return directories;
  }

  /// List of candidate absolute paths to search for fonts.
  Iterable<String?> getSearchableDirectories();
}

String? userHomeDirectory() {
  try {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  } on Exception {
    return null;
  }
}

String? environmentValue(String name) {
  try {
    final env = Platform.environment[name];
    if (env != null && env.isNotEmpty) {
      return env;
    }
    // On Windows environment keys can be presented in various cases.
    final upper = Platform.environment[name.toUpperCase()];
    if (upper != null && upper.isNotEmpty) {
      return upper;
    }
  } on Exception {
    return null;
  }
  return null;
}

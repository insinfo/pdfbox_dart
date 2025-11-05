import 'dart:io';

import 'package:logging/logging.dart';

import 'font_dir_finder.dart';
import 'native_font_dir_finder.dart';

final Logger _log = Logger('WindowsFontDirFinder');

/// Font directory finder tailored for Windows installations.
class WindowsFontDirFinder implements FontDirFinder {
  @override
  List<Directory> find() {
    final directories = <Directory>[];
    final windowsDir = _resolveWindowsDirectory();
    if (windowsDir != null && windowsDir.length > 2) {
      final trimmed = _trimTrailingSeparators(windowsDir);
      final fontsDir = Directory('$trimmed${Platform.pathSeparator}FONTS');
      _addIfReadable(fontsDir, directories);

      final drivePrefix = trimmed.substring(0, 2);
      final psFontsDir = Directory('$drivePrefix${Platform.pathSeparator}PSFONTS');
      _addIfReadable(psFontsDir, directories);
    } else {
      final windowsDirName = _resolveLegacyWindowsDirectoryName();
      for (var code = 'C'.codeUnitAt(0); code <= 'E'.codeUnitAt(0); code++) {
        final drive = String.fromCharCode(code);
        final fontsDir = Directory(
          '$drive:${Platform.pathSeparator}$windowsDirName${Platform.pathSeparator}FONTS',
        );
        if (_addIfReadable(fontsDir, directories)) {
          break;
        }
      }
      for (var code = 'C'.codeUnitAt(0); code <= 'E'.codeUnitAt(0); code++) {
        final drive = String.fromCharCode(code);
        final psFontsDir = Directory('$drive:${Platform.pathSeparator}PSFONTS');
        if (_addIfReadable(psFontsDir, directories)) {
          break;
        }
      }
    }

    final localAppData = environmentValue('LOCALAPPDATA');
    if (localAppData != null && localAppData.isNotEmpty) {
      final path = [
        localAppData,
        'Microsoft',
        'Windows',
        'Fonts',
      ].join(Platform.pathSeparator);
      _addIfReadable(Directory(path), directories);
    }
    return directories;
  }

  bool _addIfReadable(Directory directory, List<Directory> directories) {
    try {
      if (directory.existsSync()) {
        directory.statSync();
        directories.add(directory);
        return true;
      }
    } on FileSystemException catch (err, stackTrace) {
      _log.fine('Ignoring inaccessible Windows font directory ${directory.path}', err, stackTrace);
    } on Exception catch (err, stackTrace) {
      _log.fine('Ignoring Windows font directory ${directory.path} due to error', err, stackTrace);
    }
    return false;
  }

  String? _resolveWindowsDirectory() {
    final fromEnvProperty = environmentValue('windir');
    if (fromEnvProperty != null && fromEnvProperty.isNotEmpty) {
      return fromEnvProperty;
    }
    final systemRoot = environmentValue('SYSTEMROOT');
    if (systemRoot != null && systemRoot.isNotEmpty) {
      return systemRoot;
    }
    return null;
  }

  String _trimTrailingSeparators(String path) {
    var trimmed = path;
    while (trimmed.endsWith('/') || trimmed.endsWith('\\')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _resolveLegacyWindowsDirectoryName() {
    final osEnv = environmentValue('OS');
    if (osEnv != null && osEnv.toUpperCase().contains('WINDOWS NT')) {
      return 'WINNT';
    }
    return 'WINDOWS';
  }
}

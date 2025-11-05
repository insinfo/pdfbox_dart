import 'dart:io';

/// Contract for components that discover font directories in the host system.
abstract class FontDirFinder {
  /// Returns the list of directories that may contain installed fonts.
  List<Directory> find();
}

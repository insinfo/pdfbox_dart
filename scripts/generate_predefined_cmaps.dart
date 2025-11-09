import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Generates `lib/src/fontbox/cmap/predefined_cmaps.dart` from the Java resource set.
///
/// The Java resources are located under `pdfbox-java/fontbox/src/main/resources/org/apache/fontbox/cmap`.
Future<void> main(List<String> arguments) async {
  final repoRoot = Directory.current.path;
  final sourceDir = Directory(p.join(repoRoot, 'pdfbox-java', 'fontbox', 'src', 'main', 'resources',
      'org', 'apache', 'fontbox', 'cmap'));
  if (!await sourceDir.exists()) {
    stderr.writeln('Source directory not found: ${sourceDir.path}');
    exitCode = 1;
    return;
  }

  final files = await sourceDir
      .list()
      .where((entity) => entity is File)
      .cast<File>()
      .toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

  if (files.isEmpty) {
    stderr.writeln('No CMap resources found in ${sourceDir.path}');
    exitCode = 2;
    return;
  }

  final buffer = StringBuffer()
    ..writeln('// Generated file. Do not edit manually.')
    ..writeln('// ignore_for_file: constant_identifier_names')
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln('class PredefinedCMapData {')
    ..writeln('  PredefinedCMapData._();')
    ..writeln()
    ..writeln('  static final Map<String, Uint8List> _cache = <String, Uint8List>{};')
    ..writeln()
    ..writeln('  static Uint8List? getBytes(String name) {')
    ..writeln('    final cached = _cache[name];')
    ..writeln('    if (cached != null) {')
    ..writeln('      return cached;')
    ..writeln('    }')
    ..writeln('    final encoded = _data[name];')
    ..writeln('    if (encoded == null) {')
    ..writeln('      return null;')
    ..writeln('    }')
  ..writeln('    final decoded = Uint8List.fromList(base64.decode(encoded));')
    ..writeln('    _cache[name] = decoded;')
    ..writeln('    return decoded;')
    ..writeln('  }')
    ..writeln()
    ..writeln('  static const List<String> names = <String>[');

  for (final file in files) {
    final name = p.basename(file.path);
    buffer.writeln("    '$name',");
  }

  buffer
    ..writeln('  ];')
    ..writeln()
    ..writeln('  static const Map<String, String> _data = <String, String>{');

  for (final file in files) {
    final name = p.basename(file.path);
  final bytes = await file.readAsBytes();
  final encoded = base64.encode(bytes);
    buffer
      ..writeln("    '$name':\n        '$encoded',");
  }

  buffer
    ..writeln('  };')
    ..writeln('}')
    ..writeln();

  final targetPath = p.join(repoRoot, 'lib', 'src', 'fontbox', 'cmap', 'predefined_cmaps.dart');
  await File(targetPath).writeAsString(buffer.toString());
}

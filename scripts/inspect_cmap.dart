import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/otf_parser.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';

/// Utility script to inspect cmap subtables for real fonts and ensure parsing succeeds.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run scripts/inspect_cmap.dart <font-file> [<font-file> ...]');
    exitCode = 64; // EX_USAGE
    return;
  }

  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });

  final ttfParser = TtfParser();
  final otfParser = OtfParser();

  for (final path in args) {
    _inspectFont(ttfParser, otfParser, path);
  }
}

void _inspectFont(TtfParser ttfParser, OtfParser otfParser, String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Font not found: $path');
    return;
  }

  stdout.writeln('--- Inspecting $path');
  TrueTypeFont? font;
  try {
    font = _parseFont(path, ttfParser, otfParser);

    stdout.writeln('Font version: ${font.version.toStringAsFixed(3)}');
    stdout.writeln('Number of glyphs: ${font.numberOfGlyphs}');

    final cmapTable = font.getCmapTable();
    if (cmapTable == null) {
      stdout.writeln('No cmap table present.');
      return;
    }

    var index = 0;
    for (final cmap in cmapTable.cmaps) {
      stdout
        ..writeln('  Subtable #${index++}')
        ..writeln('    platformId=${cmap.platformId}, encodingId=${cmap.platformEncodingId}')
        ..writeln('    format=${cmap.format}, length=${cmap.length}, language=${cmap.language}')
        ..writeln('    mappings=${cmap.mappingCount}');

      if (cmap.mappingCount > 0) {
        final entries = cmap.characterCodeToGlyphId.entries.take(5).toList();
        if (entries.isNotEmpty) {
          stdout.writeln('    samples:');
          for (final entry in entries) {
            stdout.writeln('      ${_formatCodePoint(entry.key)} -> ${entry.value}');
          }
        }
      }

      if (cmap.format == 14) {
        _dumpVariationSequences(cmap);
      }
    }
  } on IOException catch (e) {
    stderr.writeln('Failed to parse $path: ${e.message}');
  } catch (e, stack) {
    stderr
      ..writeln('Unexpected error while parsing $path: $e')
      ..writeln(stack);
  } finally {
    font?.close();
  }
}

TrueTypeFont _parseFont(String path, TtfParser ttfParser, OtfParser otfParser) {
  final sfntTag = _readSfntTag(path);
  final preferOtf = sfntTag == _ottoTag;

  if (preferOtf) {
    return otfParser.parse(RandomAccessReadBufferedFile(path));
  }

  try {
    return ttfParser.parse(RandomAccessReadBufferedFile(path));
  } on IOException catch (e) {
    if (_shouldRetryWithOtf(e)) {
      return otfParser.parse(RandomAccessReadBufferedFile(path));
    }
    rethrow;
  }
}

const int _ottoTag = 0x4F54544F; // 'OTTO'

int? _readSfntTag(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final raf = file.openSync(mode: FileMode.read);
  try {
    final bytes = raf.readSync(4);
    if (bytes.length < 4) {
      return null;
    }
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  } finally {
    raf.closeSync();
  }
}

bool _shouldRetryWithOtf(IOException error) {
  final message = error.message.toLowerCase();
  return message.contains('cff outlines are not supported') ||
      message.contains('cff') ||
      message.contains('postscript');
}

void _dumpVariationSequences(CmapSubtable cmap) {
  final selectors = cmap.variationSelectors;
  stdout.writeln('    variationSelectors=${selectors.length}');
  var printed = 0;
  for (final selector in selectors) {
    final data = cmap.getVariationSelectorData(selector);
    if (data == null) {
      continue;
    }
    final defaultCount = data.defaultRanges.length;
    final nonDefaultCount = data.nonDefaultMappings.length;
    stdout.writeln(
      '    selector ${_formatCodePoint(selector)}: defaultRanges=$defaultCount, nonDefaultMappings=$nonDefaultCount',
    );
    if (nonDefaultCount > 0) {
      final samples = data.nonDefaultMappings.entries.take(5);
      for (final entry in samples) {
        stdout.writeln(
          '      ${_formatCodePoint(entry.key)} + ${_formatCodePoint(selector)} -> ${entry.value}',
        );
      }
    }
    printed++;
    if (printed >= 3) {
      final remaining = selectors.length - printed;
      if (remaining > 0) {
        stdout.writeln('    ... $remaining additional selectors omitted');
      }
      break;
    }
  }
}

String _formatCodePoint(int codePoint) {
  final hex = codePoint.toRadixString(16).toUpperCase();
  final padded = hex.padLeft(codePoint <= 0xFFFF ? 4 : 6, '0');
  return 'U+$padded';
}

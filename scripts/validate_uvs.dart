import 'dart:io';

import 'package:logging/logging.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/cmap_subtable.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/otf_parser.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/true_type_font.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/ttf_parser.dart';
import 'package:pdfbox_dart/src/io/exceptions.dart';
import 'package:pdfbox_dart/src/io/random_access_read_buffered_file.dart';

/// Scans fonts and validates Unicode Variation Sequences (UVS) coverage.
///
/// Usage:
///   dart run scripts/validate_uvs.dart <path> [<path> ...]
/// Paths may reference individual font files (.ttf/.otf/.ttc) or directories.
/// Directories are scanned recursively and any readable SFNT font is analysed.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exitCode = 64; // EX_USAGE
    return;
  }

  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    stderr.writeln('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });

  final fontPaths = _collectFontPaths(args);
  if (fontPaths.isEmpty) {
    stderr.writeln('No fonts found to analyse.');
    exitCode = 66; // EX_NOINPUT
    return;
  }

  final ttfParser = TtfParser();
  final otfParser = OtfParser();

  var analysed = 0;
  var withSelectors = 0;
  var totalSelectors = 0;
  var totalNonDefaultMappings = 0;
  var totalIssues = 0;

  for (final path in fontPaths) {
    final summary = await _inspectFont(path, ttfParser, otfParser);
    if (summary == null) {
      continue;
    }
    analysed++;
    stdout.writeln('=== ${summary.path}');
    stdout.writeln('  glyphs=${summary.glyphCount}, version=${summary.version}');
    if (summary.selectorSummaries.isEmpty) {
      stdout.writeln('  variationSelectors=0');
      continue;
    }

    withSelectors++;
    totalSelectors += summary.selectorSummaries.length;
    stdout.writeln('  variationSelectors=${summary.selectorSummaries.length}');
    for (final selector in summary.selectorSummaries) {
      totalNonDefaultMappings += selector.nonDefaultMappings;
      totalIssues += selector.totalIssues;
      stdout.writeln(
        '    ${selector.selectorLabel}: defaults=${selector.defaultRanges} '
        '(checked=${selector.samplesTested}, issues=${selector.defaultIssues}), '
        'nonDefault=${selector.nonDefaultMappings} '
        '(baseMissing=${selector.baseMissing}, mismatches=${selector.mappingMismatches})',
      );
    }
  }

  stdout.writeln('---');
  stdout.writeln('Fonts analysed: $analysed');
  stdout.writeln('Fonts with UVS: $withSelectors');
  stdout.writeln('Total variation selectors: $totalSelectors');
  stdout.writeln('Total non-default mappings: $totalNonDefaultMappings');
  stdout.writeln('Reported issues: $totalIssues');
}

void _printUsage() {
  stderr.writeln('Usage: dart run scripts/validate_uvs.dart <path> [<path> ...]');
  stderr.writeln('  Paths may be font files or directories (scanned recursively).');
}

List<String> _collectFontPaths(List<String> args) {
  final pending = <String>[];
  final seen = <String>{};
  for (final arg in args) {
    if (arg.trim().isEmpty) {
      continue;
    }
    final normalized = File(arg).absolute.path;
    if (seen.add(normalized)) {
      pending.add(normalized);
    }
  }

  final results = <String>[];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    final entity = FileSystemEntity.typeSync(current);
    switch (entity) {
      case FileSystemEntityType.directory:
        final dir = Directory(current);
        for (final entry in dir.listSync(recursive: false, followLinks: false)) {
          final path = entry.absolute.path;
          if (entry is Directory) {
            if (seen.add(path)) {
              pending.add(path);
            }
          } else if (entry is File) {
            if (_isFontPath(path) && seen.add(path)) {
              results.add(path);
            }
          }
        }
        break;
      case FileSystemEntityType.file:
        if (_isFontPath(current)) {
          results.add(current);
        }
        break;
      default:
        break;
    }
  }
  results.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return results;
}

bool _isFontPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc');
}

Future<_FontSummary?> _inspectFont(
  String path,
  TtfParser ttfParser,
  OtfParser otfParser,
) async {
  final file = File(path);
  if (!await file.exists()) {
    stderr.writeln('Font not found: $path');
    return null;
  }

  TrueTypeFont? font;
  try {
    font = _parseFont(path, ttfParser, otfParser);
    final glyphCount = font.numberOfGlyphs;
    final version = font.version.toStringAsFixed(3);

    final cmapLookup = font.getUnicodeCmapLookup(isStrict: false);
    if (cmapLookup is! CmapSubtable) {
      return _FontSummary(path, glyphCount, version, const <_SelectorSummary>[]);
    }

    final selectors = cmapLookup.variationSelectors.toList()..sort();
    if (selectors.isEmpty) {
      return _FontSummary(path, glyphCount, version, const <_SelectorSummary>[]);
    }

    final summaries = <_SelectorSummary>[];
    for (final selector in selectors) {
      final data = cmapLookup.getVariationSelectorData(selector);
      if (data == null) {
        continue;
      }
      final defaultIssues = _validateDefaultRanges(cmapLookup, data.defaultRanges, selector);
      final nonDefaultIssues = _validateNonDefaultMappings(cmapLookup, data.nonDefaultMappings, selector);
      summaries.add(_SelectorSummary(
        selectorLabel: _formatCodePoint(selector),
        defaultRanges: data.defaultRanges.length,
        defaultIssues: defaultIssues.issues,
        samplesTested: defaultIssues.samples,
        nonDefaultMappings: data.nonDefaultMappings.length,
        baseMissing: nonDefaultIssues.baseMissing,
        mappingMismatches: nonDefaultIssues.mismatches,
      ));
    }

    return _FontSummary(path, glyphCount, version, summaries);
  } on IOException catch (e) {
    stderr.writeln('Failed to parse $path: ${e.message}');
  } catch (e, stack) {
    stderr
      ..writeln('Unexpected error while parsing $path: $e')
      ..writeln(stack);
  } finally {
    font?.close();
  }
  return null;
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

class _DefaultValidationResult {
  const _DefaultValidationResult({required this.samples, required this.issues});

  final int samples;
  final int issues;
}

class _NonDefaultValidationResult {
  const _NonDefaultValidationResult({required this.baseMissing, required this.mismatches});

  final int baseMissing;
  final int mismatches;
}

_DefaultValidationResult _validateDefaultRanges(
  CmapSubtable cmap,
  List<CmapVariationDefaultRange> ranges,
  int selector,
) {
  var samples = 0;
  var issues = 0;
  for (final range in ranges) {
    void validatePoint(int codePoint) {
      samples++;
      if (cmap.getGlyphId(codePoint) == 0) {
        issues++;
      }
      if (!cmap.isDefaultVariation(codePoint, selector)) {
        issues++;
      }
    }

    validatePoint(range.start);
    if (range.end != range.start) {
      validatePoint(range.end);
    }
  }
  return _DefaultValidationResult(samples: samples, issues: issues);
}

_NonDefaultValidationResult _validateNonDefaultMappings(
  CmapSubtable cmap,
  Map<int, int> mappings,
  int selector,
) {
  var baseMissing = 0;
  var mismatches = 0;
  mappings.forEach((codePoint, glyphId) {
    final baseGlyph = cmap.getGlyphId(codePoint);
    if (baseGlyph == 0) {
      baseMissing++;
    }
    final variationGlyph = cmap.getGlyphId(codePoint, selector);
    if (variationGlyph != glyphId) {
      mismatches++;
    }
    if (cmap.isDefaultVariation(codePoint, selector)) {
      mismatches++;
    }
  });
  return _NonDefaultValidationResult(baseMissing: baseMissing, mismatches: mismatches);
}

class _FontSummary {
  _FontSummary(this.path, this.glyphCount, this.version, this.selectorSummaries);

  final String path;
  final int glyphCount;
  final String version;
  final List<_SelectorSummary> selectorSummaries;
}

class _SelectorSummary {
  _SelectorSummary({
    required this.selectorLabel,
    required this.defaultRanges,
    required this.defaultIssues,
    required this.samplesTested,
    required this.nonDefaultMappings,
    required this.baseMissing,
    required this.mappingMismatches,
  });

  final String selectorLabel;
  final int defaultRanges;
  final int defaultIssues;
  final int samplesTested;
  final int nonDefaultMappings;
  final int baseMissing;
  final int mappingMismatches;

  int get totalIssues => defaultIssues + baseMissing + mappingMismatches;
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

String _formatCodePoint(int codePoint) {
  final hex = codePoint.toRadixString(16).toUpperCase();
  final padded = hex.padLeft(codePoint <= 0xFFFF ? 4 : 6, '0');
  return 'U+$padded';
}

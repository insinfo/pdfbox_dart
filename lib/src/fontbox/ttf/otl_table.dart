import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// Justification (JSTF) table exposing OpenType layout metadata.
class OtlTable extends TtfTable {
  OtlTable();

  static const String tableTag = 'JSTF';
  static final Logger _log = Logger('fontbox.OtlTable');

  int _majorVersion = 0;
  int _minorVersion = 0;
  Map<String, JstfScript> _scripts = const <String, JstfScript>{};

  int get majorVersion => _majorVersion;
  int get minorVersion => _minorVersion;

  Map<String, JstfScript> get scripts => _scripts;

  JstfScript? getScript(String scriptTag) => _scripts[scriptTag];

  bool get hasScripts => _scripts.isNotEmpty;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    final tableStart = data.currentPosition;
    _majorVersion = data.readUnsignedShort();
    _minorVersion = data.readUnsignedShort();
    final scriptCount = data.readUnsignedShort();

    final scriptTags = List<String>.filled(scriptCount, '');
    final scriptOffsets = List<int>.filled(scriptCount, 0);
    for (var i = 0; i < scriptCount; i++) {
      final tag = data.readString(4);
      scriptTags[i] = tag;
      scriptOffsets[i] = data.readUnsignedShort();
      if (i > 0 && tag.compareTo(scriptTags[i - 1]) < 0) {
        _log.fine(
            'JSTF script tag $tag precedes ${scriptTags[i - 1]}, entries should be sorted');
      }
    }

    final scripts = <String, JstfScript>{};
    for (var i = 0; i < scriptCount; i++) {
      final offset = scriptOffsets[i];
      if (offset == 0) {
        _log.fine('Skipping JSTF script ${scriptTags[i]} with zero offset');
        continue;
      }
      final absoluteOffset = tableStart + offset;
      try {
        scripts[scriptTags[i]] = _readScript(data, absoluteOffset);
      } on IOException catch (error, stackTrace) {
        _log.warning(
            'Failed to read JSTF script ${scriptTags[i]}', error, stackTrace);
      }
    }

    _scripts = Map<String, JstfScript>.unmodifiable(scripts);
    setInitialized(true);
  }

  JstfScript _readScript(TtfDataStream data, int offset) {
    data.seek(offset);
    final extenderGlyphOffset = data.readUnsignedShort();
    final defaultLangSysOffset = data.readUnsignedShort();
    final langSysCount = data.readUnsignedShort();
    final langSysTags = List<String>.filled(langSysCount, '');
    final langSysOffsets = List<int>.filled(langSysCount, 0);
    for (var i = 0; i < langSysCount; i++) {
      langSysTags[i] = data.readString(4);
      langSysOffsets[i] = data.readUnsignedShort();
    }

    final extenderGlyphs = extenderGlyphOffset == 0
        ? const <int>[]
        : _readExtenderGlyphs(data, offset + extenderGlyphOffset);

    JstfLangSys? defaultLangSys;
    if (defaultLangSysOffset != 0) {
      defaultLangSys = _readLangSys(data, offset + defaultLangSysOffset);
    }

    final langSystems = <String, JstfLangSys>{};
    for (var i = 0; i < langSysCount; i++) {
      final langOffset = langSysOffsets[i];
      if (langOffset == 0) {
        _log.fine('Skipping JSTF lang sys ${langSysTags[i]} with zero offset');
        continue;
      }
      langSystems[langSysTags[i]] = _readLangSys(data, offset + langOffset);
    }

    return JstfScript(
      extenderGlyphs: extenderGlyphs,
      defaultLangSys: defaultLangSys,
      langSysRecords: langSystems,
    );
  }

  List<int> _readExtenderGlyphs(TtfDataStream data, int offset) {
    data.seek(offset);
    final glyphCount = data.readUnsignedShort();
    if (glyphCount <= 0) {
      return const <int>[];
    }
    final glyphs = data.readUnsignedShortArray(glyphCount);
    return List<int>.unmodifiable(glyphs);
  }

  JstfLangSys _readLangSys(TtfDataStream data, int offset) {
    data.seek(offset);
    final priorityCount = data.readUnsignedShort();
    final priorityOffsets = data.readUnsignedShortArray(priorityCount);
    final priorities = <JstfPriority>[];
    for (var i = 0; i < priorityCount; i++) {
      final relativeOffset = priorityOffsets[i];
      if (relativeOffset == 0) {
        continue;
      }
      priorities.add(_readPriority(data, offset + relativeOffset));
    }
    return JstfLangSys(priorities);
  }

  JstfPriority _readPriority(TtfDataStream data, int offset) {
    data.seek(offset);
    final gsubShrinkEnable = data.readUnsignedShort();
    final gsubShrinkDisable = data.readUnsignedShort();
    final gposShrinkEnable = data.readUnsignedShort();
    final gposShrinkDisable = data.readUnsignedShort();
    final shrinkageMaxOffset = data.readUnsignedShort();
    final gsubExtendEnable = data.readUnsignedShort();
    final gsubExtendDisable = data.readUnsignedShort();
    final gposExtendEnable = data.readUnsignedShort();
    final gposExtendDisable = data.readUnsignedShort();
    final extensionMaxOffset = data.readUnsignedShort();

    return JstfPriority(
      gsubShrinkageEnable:
          _readModListIfPresent(data, offset, gsubShrinkEnable),
      gsubShrinkageDisable:
          _readModListIfPresent(data, offset, gsubShrinkDisable),
      gposShrinkageEnable:
          _readModListIfPresent(data, offset, gposShrinkEnable),
      gposShrinkageDisable:
          _readModListIfPresent(data, offset, gposShrinkDisable),
      shrinkageMax: _readJstfMaxIfPresent(data, offset, shrinkageMaxOffset),
      gsubExtensionEnable:
          _readModListIfPresent(data, offset, gsubExtendEnable),
      gsubExtensionDisable:
          _readModListIfPresent(data, offset, gsubExtendDisable),
      gposExtensionEnable:
          _readModListIfPresent(data, offset, gposExtendEnable),
      gposExtensionDisable:
          _readModListIfPresent(data, offset, gposExtendDisable),
      extensionMax: _readJstfMaxIfPresent(data, offset, extensionMaxOffset),
    );
  }

  JstfModList? _readModListIfPresent(
      TtfDataStream data, int baseOffset, int relativeOffset) {
    if (relativeOffset == 0) {
      return null;
    }
    return _readModList(data, baseOffset + relativeOffset);
  }

  JstfModList _readModList(TtfDataStream data, int offset) {
    data.seek(offset);
    final lookupCount = data.readUnsignedShort();
    if (lookupCount == 0) {
      return JstfModList(const <int>[]);
    }
    final indices = data.readUnsignedShortArray(lookupCount);
    return JstfModList(indices);
  }

  JstfMax? _readJstfMaxIfPresent(
      TtfDataStream data, int baseOffset, int relativeOffset) {
    if (relativeOffset == 0) {
      return null;
    }
    return _readJstfMax(data, baseOffset + relativeOffset);
  }

  JstfMax _readJstfMax(TtfDataStream data, int offset) {
    data.seek(offset);
    final lookupCount = data.readUnsignedShort();
    if (lookupCount == 0) {
      return JstfMax(const <int>[]);
    }
    final lookupOffsets = data.readUnsignedShortArray(lookupCount);
    return JstfMax(lookupOffsets);
  }
}

/// JSTF script definition containing language-specific justification data.
class JstfScript {
  JstfScript({
    required List<int> extenderGlyphs,
    this.defaultLangSys,
    required Map<String, JstfLangSys> langSysRecords,
  })  : extenderGlyphs = List<int>.unmodifiable(extenderGlyphs),
        langSysRecords = Map<String, JstfLangSys>.unmodifiable(langSysRecords);

  final List<int> extenderGlyphs;
  final JstfLangSys? defaultLangSys;
  final Map<String, JstfLangSys> langSysRecords;

  bool get hasExtenderGlyphs => extenderGlyphs.isNotEmpty;
}

/// Language system definition containing priority-ordered adjustments.
class JstfLangSys {
  JstfLangSys(List<JstfPriority> priorities)
      : priorities = List<JstfPriority>.unmodifiable(priorities);

  final List<JstfPriority> priorities;

  bool get hasPriorities => priorities.isNotEmpty;
}

/// Set of justification actions scoped to a specific priority level.
class JstfPriority {
  const JstfPriority({
    this.gsubShrinkageEnable,
    this.gsubShrinkageDisable,
    this.gposShrinkageEnable,
    this.gposShrinkageDisable,
    this.shrinkageMax,
    this.gsubExtensionEnable,
    this.gsubExtensionDisable,
    this.gposExtensionEnable,
    this.gposExtensionDisable,
    this.extensionMax,
  });

  final JstfModList? gsubShrinkageEnable;
  final JstfModList? gsubShrinkageDisable;
  final JstfModList? gposShrinkageEnable;
  final JstfModList? gposShrinkageDisable;
  final JstfMax? shrinkageMax;
  final JstfModList? gsubExtensionEnable;
  final JstfModList? gsubExtensionDisable;
  final JstfModList? gposExtensionEnable;
  final JstfModList? gposExtensionDisable;
  final JstfMax? extensionMax;

  bool get hasShrinkageActions =>
      gsubShrinkageEnable != null ||
      gsubShrinkageDisable != null ||
      gposShrinkageEnable != null ||
      gposShrinkageDisable != null ||
      shrinkageMax != null;

  bool get hasExtensionActions =>
      gsubExtensionEnable != null ||
      gsubExtensionDisable != null ||
      gposExtensionEnable != null ||
      gposExtensionDisable != null ||
      extensionMax != null;
}

/// Indices of GSUB/GPOS lookups affected by a JSTF action.
class JstfModList {
  JstfModList(List<int> lookupIndices)
      : lookupIndices = List<int>.unmodifiable(lookupIndices);

  final List<int> lookupIndices;

  bool get isEmpty => lookupIndices.isEmpty;
}

/// Maximum justification adjustments defined within the JSTF table.
class JstfMax {
  JstfMax(List<int> lookupOffsets)
      : lookupOffsets = List<int>.unmodifiable(lookupOffsets);

  final List<int> lookupOffsets;

  bool get isEmpty => lookupOffsets.isEmpty;
}

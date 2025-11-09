import '../otl_table.dart';

/// Modes supported when applying JSTF priorities.
enum JstfAdjustmentMode { none, shrink, extend }

/// Provides lookup enable/disable lists derived from JSTF priorities.
class JstfLookupControl {
  JstfLookupControl({
    Set<int>? enabledGsubLookups,
    Set<int>? disabledGsubLookups,
    Set<int>? enabledGposLookups,
    Set<int>? disabledGposLookups,
  })  : enabledGsubLookups =
            Set<int>.unmodifiable(enabledGsubLookups ?? const <int>{}),
        disabledGsubLookups =
            Set<int>.unmodifiable(disabledGsubLookups ?? const <int>{}),
        enabledGposLookups =
            Set<int>.unmodifiable(enabledGposLookups ?? const <int>{}),
    disabledGposLookups =
      Set<int>.unmodifiable(disabledGposLookups ?? const <int>{});

  static final JstfLookupControl empty = JstfLookupControl();

  final Set<int> enabledGsubLookups;
  final Set<int> disabledGsubLookups;
  final Set<int> enabledGposLookups;
  final Set<int> disabledGposLookups;

  bool get hasEnabledGsubLookups => enabledGsubLookups.isNotEmpty;
  bool get hasEnabledGposLookups => enabledGposLookups.isNotEmpty;
  bool get isEmpty =>
      enabledGsubLookups.isEmpty &&
      disabledGsubLookups.isEmpty &&
      enabledGposLookups.isEmpty &&
      disabledGposLookups.isEmpty;

  bool isGsubLookupEnabled(int lookupIndex) =>
      enabledGsubLookups.contains(lookupIndex);

  bool isGsubLookupDisabled(int lookupIndex) =>
      disabledGsubLookups.contains(lookupIndex);

  bool isGposLookupEnabled(int lookupIndex) =>
      enabledGposLookups.contains(lookupIndex);

  bool isGposLookupDisabled(int lookupIndex) =>
      disabledGposLookups.contains(lookupIndex);

  JstfLookupControl merge(JstfLookupControl other) => JstfLookupControl(
        enabledGsubLookups: <int>{
          ...enabledGsubLookups,
          ...other.enabledGsubLookups,
        },
        disabledGsubLookups: <int>{
          ...disabledGsubLookups,
          ...other.disabledGsubLookups,
        },
        enabledGposLookups: <int>{
          ...enabledGposLookups,
          ...other.enabledGposLookups,
        },
        disabledGposLookups: <int>{
          ...disabledGposLookups,
          ...other.disabledGposLookups,
        },
      );
}

/// Evaluates JSTF priorities and produces lookup controls.
class JstfPriorityController {
  JstfPriorityController(this.script, {this.languageTag});

  final JstfScript script;
  final String? languageTag;

  JstfLookupControl evaluate(JstfAdjustmentMode mode) {
    if (mode == JstfAdjustmentMode.none) {
      return JstfLookupControl.empty;
    }
    final langSys = _resolveLangSys();
    if (langSys == null || !langSys.hasPriorities) {
      return JstfLookupControl.empty;
    }

    final enableGsub = <int>{};
    final disableGsub = <int>{};
    final enableGpos = <int>{};
    final disableGpos = <int>{};

    for (final priority in langSys.priorities) {
      final modLists = _selectModLists(priority, mode);
      if (modLists == null) {
        continue;
      }
      enableGsub.addAll(modLists.enableGsub);
      disableGsub.addAll(modLists.disableGsub);
      enableGpos.addAll(modLists.enableGpos);
      disableGpos.addAll(modLists.disableGpos);
    }

    if (enableGsub.isEmpty &&
        disableGsub.isEmpty &&
        enableGpos.isEmpty &&
        disableGpos.isEmpty) {
      return JstfLookupControl.empty;
    }

    return JstfLookupControl(
      enabledGsubLookups: enableGsub,
      disabledGsubLookups: disableGsub,
      enabledGposLookups: enableGpos,
      disabledGposLookups: disableGpos,
    );
  }

  JstfLangSys? _resolveLangSys() {
    if (languageTag != null) {
      final langSys = script.langSysRecords[languageTag];
      if (langSys != null) {
        return langSys;
      }
    }
    return script.defaultLangSys;
  }

  _PrioritySelection? _selectModLists(
    JstfPriority priority,
    JstfAdjustmentMode mode,
  ) {
    switch (mode) {
      case JstfAdjustmentMode.none:
        return null;
      case JstfAdjustmentMode.shrink:
        return _PrioritySelection(
          enableGsub: _toSet(priority.gsubShrinkageEnable),
          disableGsub: _toSet(priority.gsubShrinkageDisable),
          enableGpos: _toSet(priority.gposShrinkageEnable),
          disableGpos: _toSet(priority.gposShrinkageDisable),
        );
      case JstfAdjustmentMode.extend:
        return _PrioritySelection(
          enableGsub: _toSet(priority.gsubExtensionEnable),
          disableGsub: _toSet(priority.gsubExtensionDisable),
          enableGpos: _toSet(priority.gposExtensionEnable),
          disableGpos: _toSet(priority.gposExtensionDisable),
        );
    }
  }

  Set<int> _toSet(JstfModList? list) =>
      list == null ? <int>{} : list.lookupIndices.toSet();
}

class _PrioritySelection {
  _PrioritySelection({
    required this.enableGsub,
    required this.disableGsub,
    required this.enableGpos,
    required this.disableGpos,
  });

  final Set<int> enableGsub;
  final Set<int> disableGsub;
  final Set<int> enableGpos;
  final Set<int> disableGpos;
}

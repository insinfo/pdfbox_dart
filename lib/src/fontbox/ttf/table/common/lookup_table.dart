import 'lookup_sub_table.dart';

class LookupTable {
  LookupTable(
    this.lookupType,
    this.lookupFlag,
    this.markFilteringSet,
    List<LookupSubTable> subTables,
  ) : subTables = List<LookupSubTable>.unmodifiable(subTables);

  final int lookupType;
  final int lookupFlag;
  final int markFilteringSet;
  final List<LookupSubTable> subTables;

  @override
  String toString() =>
      'LookupTable[lookupType=$lookupType,lookupFlag=$lookupFlag,markFilteringSet=$markFilteringSet]';
}

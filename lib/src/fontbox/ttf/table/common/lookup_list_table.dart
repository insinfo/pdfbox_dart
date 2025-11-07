import 'lookup_table.dart';

class LookupListTable {
  LookupListTable(this.lookupCount, List<LookupTable> lookups)
      : lookups = List<LookupTable>.unmodifiable(lookups);

  final int lookupCount;
  final List<LookupTable> lookups;

  @override
  String toString() => 'LookupListTable[lookupCount=$lookupCount]';
}

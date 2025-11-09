/// Value object representing a CIDSystemInfo entry.
class CidSystemInfo {
  const CidSystemInfo({required this.registry, required this.ordering, required this.supplement});

  final String registry;
  final String ordering;
  final int supplement;

  @override
  String toString() => '$registry-$ordering-$supplement';
}

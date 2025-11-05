import 'dart:collection';

import 'composite_part.dart';

class Composite {
  Composite(this.name);

  final String name;
  final List<CompositePart> _parts = <CompositePart>[];

  void addPart(CompositePart part) {
    _parts.add(part);
  }

  List<CompositePart> get parts => UnmodifiableListView(_parts);
}

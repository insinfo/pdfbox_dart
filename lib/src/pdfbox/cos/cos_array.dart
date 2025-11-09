import 'dart:collection';

import 'cos_base.dart';

class COSArray extends COSBase with IterableMixin<COSBase> {
  final List<COSBase> _items = <COSBase>[];

  void add(COSObjectable value) {
    _items.add(value.cosObject);
  }

  void addObject(COSBase value) {
    _items.add(value);
  }

  void insert(int index, COSObjectable value) {
    _items.insert(index, value.cosObject);
  }

  COSBase operator [](int index) => _items[index];

  COSBase getObject(int index) => _items[index];

  void operator []=(int index, COSObjectable value) {
    _items[index] = value.cosObject;
  }

  void removeAt(int index) {
    _items.removeAt(index);
  }

  void clear() {
    _items.clear();
  }

  int get length => _items.length;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  List<COSBase> toList({bool growable = true}) =>
      List<COSBase>.from(_items, growable: growable);

  @override
  Iterator<COSBase> get iterator => _items.iterator;
}

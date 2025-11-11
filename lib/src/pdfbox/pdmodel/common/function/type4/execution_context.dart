class ExecutionContext<T> {
  ExecutionContext(this.operators);

  final T operators;
  final PostScriptStack stack = PostScriptStack();

  num popNumber() {
    final value = stack.pop();
    if (value is num) {
      return value;
    }
    throw StateError('Expected numeric value on stack');
  }

  int popInt() {
    final value = stack.pop();
    if (value is int) {
      return value;
    }
    throw StateError('Expected int value on stack');
  }

  double popReal() {
    final value = stack.pop();
    if (value is num) {
      return value.toDouble();
    }
    throw StateError('Expected numeric value on stack');
  }
}

class PostScriptStack {
  final List<dynamic> _items = <dynamic>[];

  void push(dynamic value) => _items.add(value);

  dynamic pop() {
    if (_items.isEmpty) {
      throw StateError('Stack underflow');
    }
    return _items.removeLast();
  }

  dynamic peek() {
    if (_items.isEmpty) {
      throw StateError('Stack underflow');
    }
    return _items.last;
  }

  bool get isEmpty => _items.isEmpty;

  int get length => _items.length;

  void addAll(Iterable<dynamic> values) => _items.addAll(values);

  dynamic operator [](int index) => _items[index];

  List<dynamic> sublist(int start, [int? end]) => _items.sublist(start, end);
}

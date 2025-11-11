import 'execution_context.dart';
import 'operator.dart';

class StackOperators {
  StackOperators._();

  static final Operator copy = _Copy();
  static final Operator dup = _Dup();
  static final Operator exch = _Exch();
  static final Operator index = _Index();
  static final Operator pop = _Pop();
  static final Operator roll = _Roll();
}

class _Copy implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final nValue = context.popNumber();
    final n = nValue.toInt();
    if (n <= 0) {
      return;
    }
    final size = stack.length;
    if (n > size) {
      throw StateError('Not enough elements for copy operator');
    }
    final copy = List<dynamic>.from(stack.sublist(size - n));
    stack.addAll(copy);
  }
}

class _Dup implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    stack.push(stack.peek());
  }
}

class _Exch implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final second = stack.pop();
    final first = stack.pop();
    stack.push(second);
    stack.push(first);
  }
}

class _Index implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final nValue = context.popNumber();
    final n = nValue.toInt();
    if (n < 0) {
      throw ArgumentError('rangecheck: $n');
    }
    final size = stack.length;
    if (n >= size) {
      throw StateError('Index out of range for index operator');
    }
    stack.push(stack[size - n - 1]);
  }
}

class _Pop implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    context.stack.pop();
  }
}

class _Roll implements Operator {
  @override
  void execute(ExecutionContext context) {
    final stack = context.stack;
    final jValue = context.popNumber();
    final nValue = context.popNumber();
    final j = jValue.toInt();
    final n = nValue.toInt();
    if (j == 0) {
      return;
    }
    if (n < 0) {
      throw ArgumentError('rangecheck: $n');
    }
    if (n == 0) {
      return;
    }
    if (n > stack.length) {
      throw StateError('Not enough elements for roll operator');
    }
    final rolled = <dynamic>[];
    final moved = <dynamic>[];
    if (j < 0) {
      final n1 = n + j;
      for (var i = 0; i < n1; ++i) {
        moved.insert(0, stack.pop());
      }
      for (var i = j; i < 0; ++i) {
        rolled.insert(0, stack.pop());
      }
      stack.addAll(moved);
      stack.addAll(rolled);
    } else {
      final n1 = n - j;
      for (var i = j; i > 0; --i) {
        rolled.insert(0, stack.pop());
      }
      for (var i = 0; i < n1; ++i) {
        moved.insert(0, stack.pop());
      }
      stack.addAll(rolled);
      stack.addAll(moved);
    }
  }
}

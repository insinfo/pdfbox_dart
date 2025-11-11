import 'execution_context.dart';
import 'operator.dart';

class BitwiseOperators {
  BitwiseOperators._();

  static final Operator and = _And();
  static final Operator bitshift = _Bitshift();
  static final Operator falseOperator = _False();
  static final Operator not = _Not();
  static final Operator or = _Or();
  static final Operator trueOperator = _True();
  static final Operator xor = _Xor();
}

abstract class _AbstractLogicalOperator implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final op2 = stack.pop();
    final op1 = stack.pop();
    if (op1 is bool && op2 is bool) {
      stack.push(applyForBoolean(op1, op2));
    } else if (op1 is int && op2 is int) {
      stack.push(applyForInteger(op1, op2));
    } else {
      throw StateError('Operands must be bool/bool or int/int');
    }
  }

  bool applyForBoolean(bool a, bool b);

  int applyForInteger(int a, int b);
}

class _And extends _AbstractLogicalOperator {
  @override
  bool applyForBoolean(bool a, bool b) => a && b;

  @override
  int applyForInteger(int a, int b) => a & b;
}

class _Bitshift implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final shift = stack.pop();
    final value = stack.pop();
    if (shift is! int || value is! int) {
      throw StateError('Operands must be integers');
    }
    if (shift < 0) {
      stack.push(value >> shift.abs());
    } else {
      stack.push(value << shift);
    }
  }
}

class _False implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    context.stack.push(false);
  }
}

class _Not implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.stack.pop();
    if (value is bool) {
      context.stack.push(!value);
    } else if (value is int) {
      context.stack.push(-value);
    } else {
      throw StateError('Operand must be bool or int');
    }
  }
}

class _Or extends _AbstractLogicalOperator {
  @override
  bool applyForBoolean(bool a, bool b) => a || b;

  @override
  int applyForInteger(int a, int b) => a | b;
}

class _True implements Operator {
  @override
  void execute(ExecutionContext context) {
    context.stack.push(true);
  }
}

class _Xor extends _AbstractLogicalOperator {
  @override
  bool applyForBoolean(bool a, bool b) => a ^ b;

  @override
  int applyForInteger(int a, int b) => a ^ b;
}

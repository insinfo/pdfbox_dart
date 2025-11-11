import 'execution_context.dart';
import 'operator.dart';

class RelationalOperators {
  RelationalOperators._();

  static final Operator eq = _Eq();
  static final Operator ge = _Ge();
  static final Operator gt = _Gt();
  static final Operator le = _Le();
  static final Operator lt = _Lt();
  static final Operator ne = _Ne();
}

class _Eq implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final op2 = stack.pop();
    final op1 = stack.pop();
    stack.push(_isEqual(op1, op2));
  }

  bool _isEqual(dynamic op1, dynamic op2) {
    if (op1 is num && op2 is num) {
      return op1.toDouble() == op2.toDouble();
    }
    return op1 == op2;
  }
}

abstract class _AbstractNumberComparisonOperator implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final op2 = stack.pop();
    final op1 = stack.pop();
    if (op1 is! num || op2 is! num) {
      throw StateError('Operands must be numeric');
    }
    stack.push(compare(op1.toDouble(), op2.toDouble()));
  }

  bool compare(double a, double b);
}

class _Ge extends _AbstractNumberComparisonOperator {
  @override
  bool compare(double a, double b) => a >= b;
}

class _Gt extends _AbstractNumberComparisonOperator {
  @override
  bool compare(double a, double b) => a > b;
}

class _Le extends _AbstractNumberComparisonOperator {
  @override
  bool compare(double a, double b) => a <= b;
}

class _Lt extends _AbstractNumberComparisonOperator {
  @override
  bool compare(double a, double b) => a < b;
}

class _Ne extends _Eq {
  @override
  bool _isEqual(dynamic op1, dynamic op2) => !super._isEqual(op1, op2);
}

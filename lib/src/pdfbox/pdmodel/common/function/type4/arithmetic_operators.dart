import 'dart:math' as math;

import 'execution_context.dart';
import 'operator.dart';

class ArithmeticOperators {
  ArithmeticOperators._();

  static final Operator abs = _Abs();
  static final Operator add = _Add();
  static final Operator atan = _Atan();
  static final Operator ceiling = _Ceiling();
  static final Operator cos = _Cos();
  static final Operator cvi = _Cvi();
  static final Operator cvr = _Cvr();
  static final Operator div = _Div();
  static final Operator exp = _Exp();
  static final Operator floor = _Floor();
  static final Operator idiv = _IDiv();
  static final Operator ln = _Ln();
  static final Operator log = _Log();
  static final Operator mod = _Mod();
  static final Operator mul = _Mul();
  static final Operator neg = _Neg();
  static final Operator round = _Round();
  static final Operator sin = _Sin();
  static final Operator sqrt = _Sqrt();
  static final Operator sub = _Sub();
  static final Operator truncate = _Truncate();
}

class _Abs implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    if (value is int) {
      context.stack.push(value.abs());
    } else {
      context.stack.push(value.abs());
    }
  }
}

class _Add implements Operator {
  static const int _minInt32 = -0x80000000;
  static const int _maxInt32 = 0x7fffffff;

  @override
  void execute(ExecutionContext<dynamic> context) {
    final num2 = context.popNumber();
    final num1 = context.popNumber();
    if (num1 is int && num2 is int) {
      final sum = num1 + num2;
      if (sum < _minInt32 || sum > _maxInt32) {
        context.stack.push(sum.toDouble());
      } else {
        context.stack.push(sum);
      }
    } else {
      context.stack.push(num1.toDouble() + num2.toDouble());
    }
  }
}

class _Atan implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final den = context.popReal();
    final num = context.popReal();
    var atan = math.atan2(num, den);
    atan = (atan * 180 / math.pi) % 360;
    if (atan < 0) {
      atan += 360;
    }
    context.stack.push(atan);
  }
}

class _Ceiling implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    if (value is int) {
      context.stack.push(value);
    } else {
      context.stack.push(value.toDouble().ceilToDouble());
    }
  }
}

class _Cos implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final angle = context.popReal();
    final result = math.cos(angle * math.pi / 180);
    context.stack.push(result);
  }
}

class _Cvi implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    context.stack.push(value.toInt());
  }
}

class _Cvr implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    context.stack.push(value.toDouble());
  }
}

class _Div implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final num2 = context.popNumber();
    final num1 = context.popNumber();
    context.stack.push(num1.toDouble() / num2.toDouble());
  }
}

class _Exp implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final exponent = context.popNumber();
    final base = context.popNumber();
    final value = math.pow(base.toDouble(), exponent.toDouble());
    context.stack.push(value.toDouble());
  }
}

class _Floor implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    if (value is int) {
      context.stack.push(value);
    } else {
      context.stack.push(value.toDouble().floorToDouble());
    }
  }
}

class _IDiv implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final num2 = context.popInt();
    final num1 = context.popInt();
    context.stack.push(num1 ~/ num2);
  }
}

class _Ln implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    context.stack.push(math.log(value.toDouble()));
  }
}

class _Log implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    context.stack.push(math.log(value.toDouble()) / math.ln10);
  }
}

class _Mod implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final num2 = context.popInt();
    final num1 = context.popInt();
    context.stack.push(num1 % num2);
  }
}

class _Mul implements Operator {
  static const int _minInt32 = -0x80000000;
  static const int _maxInt32 = 0x7fffffff;

  @override
  void execute(ExecutionContext<dynamic> context) {
    final num2 = context.popNumber();
    final num1 = context.popNumber();
    if (num1 is int && num2 is int) {
      final product = num1 * num2;
      if (product < _minInt32 || product > _maxInt32) {
        context.stack.push(product.toDouble());
      } else {
        context.stack.push(product);
      }
    } else {
      context.stack.push(num1.toDouble() * num2.toDouble());
    }
  }
}

class _Neg implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    if (value is int) {
      if (value == -0x80000000) {
        context.stack.push(-value.toDouble());
      } else {
        context.stack.push(-value);
      }
    } else {
      context.stack.push(-value.toDouble());
    }
  }
}

class _Round implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final value = context.popNumber();
    if (value is int) {
      context.stack.push(value);
    } else {
      context.stack.push(value.toDouble().roundToDouble());
    }
  }
}

class _Sin implements Operator {
  @override
  void execute(ExecutionContext context) {
    final angle = context.popReal();
    final result = math.sin(angle * math.pi / 180);
    context.stack.push(result);
  }
}

class _Sqrt implements Operator {
  @override
  void execute(ExecutionContext context) {
    final value = context.popReal();
    if (value < 0) {
      throw ArgumentError('argument must be nonnegative');
    }
    context.stack.push(math.sqrt(value));
  }
}

class _Sub implements Operator {
  static const int _minInt32 = -0x80000000;
  static const int _maxInt32 = 0x7fffffff;

  @override
  void execute(ExecutionContext context) {
    final num2 = context.popNumber();
    final num1 = context.popNumber();
    if (num1 is int && num2 is int) {
      final result = num1 - num2;
      if (result < _minInt32 || result > _maxInt32) {
        context.stack.push(result.toDouble());
      } else {
        context.stack.push(result);
      }
    } else {
      context.stack.push(num1.toDouble() - num2.toDouble());
    }
  }
}

class _Truncate implements Operator {
  @override
  void execute(ExecutionContext context) {
    final value = context.popNumber();
    if (value is int) {
      context.stack.push(value);
    } else {
      context.stack.push(value.toDouble().truncateToDouble());
    }
  }
}

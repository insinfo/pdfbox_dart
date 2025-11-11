import 'arithmetic_operators.dart';
import 'bitwise_operators.dart';
import 'conditional_operators.dart';
import 'operator.dart';
import 'relational_operators.dart';
import 'stack_operators.dart';

class Operators {
  Operators() {
    _operators.addAll({
      'add': ArithmeticOperators.add,
      'abs': ArithmeticOperators.abs,
      'atan': ArithmeticOperators.atan,
      'ceiling': ArithmeticOperators.ceiling,
      'cos': ArithmeticOperators.cos,
      'cvi': ArithmeticOperators.cvi,
      'cvr': ArithmeticOperators.cvr,
      'div': ArithmeticOperators.div,
      'exp': ArithmeticOperators.exp,
      'floor': ArithmeticOperators.floor,
      'idiv': ArithmeticOperators.idiv,
      'ln': ArithmeticOperators.ln,
      'log': ArithmeticOperators.log,
      'mod': ArithmeticOperators.mod,
      'mul': ArithmeticOperators.mul,
      'neg': ArithmeticOperators.neg,
      'round': ArithmeticOperators.round,
      'sin': ArithmeticOperators.sin,
      'sqrt': ArithmeticOperators.sqrt,
      'sub': ArithmeticOperators.sub,
      'truncate': ArithmeticOperators.truncate,
      'and': BitwiseOperators.and,
      'bitshift': BitwiseOperators.bitshift,
      'eq': RelationalOperators.eq,
      'false': BitwiseOperators.falseOperator,
      'ge': RelationalOperators.ge,
      'gt': RelationalOperators.gt,
      'le': RelationalOperators.le,
      'lt': RelationalOperators.lt,
      'ne': RelationalOperators.ne,
      'not': BitwiseOperators.not,
      'or': BitwiseOperators.or,
      'true': BitwiseOperators.trueOperator,
      'xor': BitwiseOperators.xor,
      'if': ConditionalOperators.ifOperator,
      'ifelse': ConditionalOperators.ifelse,
      'copy': StackOperators.copy,
      'dup': StackOperators.dup,
      'exch': StackOperators.exch,
      'index': StackOperators.index,
      'pop': StackOperators.pop,
      'roll': StackOperators.roll,
    });
  }

  final Map<String, Operator> _operators = <String, Operator>{};

  Operator? getOperator(String name) => _operators[name];
}

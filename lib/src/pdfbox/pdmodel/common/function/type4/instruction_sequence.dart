import 'execution_context.dart';
import 'operators.dart';

class InstructionSequence {
  final List<dynamic> _instructions = <dynamic>[];

  void addName(String name) {
    _instructions.add(name);
  }

  void addInteger(int value) {
    _instructions.add(value);
  }

  void addReal(double value) {
    _instructions.add(value);
  }

  void addBoolean(bool value) {
    _instructions.add(value);
  }

  void addProc(InstructionSequence child) {
    _instructions.add(child);
  }

  void execute(ExecutionContext<dynamic> context) {
    final operators = context.operators as Operators;
    final stack = context.stack;
    for (final instruction in _instructions) {
      if (instruction is String) {
        final operator = operators.getOperator(instruction);
        if (operator == null) {
          throw UnsupportedError('Unknown operator or name: $instruction');
        }
        operator.execute(context);
      } else {
        stack.push(instruction);
      }
    }

    while (!stack.isEmpty && stack.peek() is InstructionSequence) {
      final nested = stack.pop() as InstructionSequence;
      nested.execute(context);
    }
  }
}

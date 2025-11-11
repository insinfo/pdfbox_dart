import 'execution_context.dart';
import 'instruction_sequence.dart';
import 'operator.dart';

class ConditionalOperators {
  ConditionalOperators._();

  static final Operator ifOperator = _If();
  static final Operator ifelse = _IfElse();
}

class _If implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final proc = stack.pop();
    final condition = stack.pop();
    if (proc is! InstructionSequence || condition is! bool) {
      throw StateError('Invalid operands for if operator');
    }
    if (condition) {
      proc.execute(context);
    }
  }
}

class _IfElse implements Operator {
  @override
  void execute(ExecutionContext<dynamic> context) {
    final stack = context.stack;
    final proc2 = stack.pop();
    final proc1 = stack.pop();
    final condition = stack.pop();
    if (proc1 is! InstructionSequence ||
        proc2 is! InstructionSequence ||
        condition is! bool) {
      throw StateError('Invalid operands for ifelse operator');
    }
    if (condition) {
      proc1.execute(context);
    } else {
      proc2.execute(context);
    }
  }
}

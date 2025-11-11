import 'execution_context.dart';

abstract class Operator {
  void execute(ExecutionContext<dynamic> context);
}

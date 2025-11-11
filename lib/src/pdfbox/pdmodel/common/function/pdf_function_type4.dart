import 'dart:convert';

import '../../../cos/cos_base.dart';
import '../../../cos/cos_stream.dart';
import 'pdf_function.dart';
import 'type4/execution_context.dart';
import 'type4/instruction_sequence.dart';
import 'type4/instruction_sequence_builder.dart';
import 'type4/operators.dart';

class PDFunctionType4 extends PDFunction {
  PDFunctionType4(COSBase? function) : super(function) {
    _instructions = InstructionSequenceBuilder.parse(_loadProgram());
  }

  static final Operators _operators = Operators();
  late final InstructionSequence _instructions;

  @override
  int get functionType => 4;

  @override
  List<double> eval(List<double> input) {
  final context = ExecutionContext<Operators>(_operators);
    for (var i = 0; i < input.length; ++i) {
      final domain = getDomainForInput(i);
      final value = clipValue(input[i], domain.min, domain.max);
      context.stack.push(value);
    }

    _instructions.execute(context);

    final expected = numberOfOutputParameters;
    final actual = context.stack.length;
    if (actual < expected) {
      throw StateError(
        'Type 4 function returned $actual values but expected at least $expected',
      );
    }

    final results = List<double>.filled(expected, 0.0);
    for (var i = expected - 1; i >= 0; --i) {
      final range = getRangeForOutput(i);
      final value = context.popReal();
      results[i] = clipValue(value, range.min, range.max);
    }
    return results;
  }

  String _loadProgram() {
    final base = cosObject;
    if (base is COSStream) {
      final decoded = base.decode();
      final bytes = decoded ?? base.encodedBytes();
      if (bytes != null) {
        return latin1.decode(bytes, allowInvalid: true);
      }
    }
    throw StateError('Type 4 function must be backed by a stream');
  }
}

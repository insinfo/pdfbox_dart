import 'instruction_sequence.dart';
import 'parser.dart';

class InstructionSequenceBuilder extends AbstractSyntaxHandler {
  InstructionSequenceBuilder._() {
    _sequenceStack.add(_mainSequence);
  }

  static final RegExp _integerPattern = RegExp(r'^[+\-]?\d+$');
  static final RegExp _realPattern =
    RegExp(r'^[+\-]?\d*\.\d*(?:[Ee][+\-]?\d+)?$');

  final InstructionSequence _mainSequence = InstructionSequence();
  final List<InstructionSequence> _sequenceStack = <InstructionSequence>[];

  static InstructionSequence parse(String text) {
    final builder = InstructionSequenceBuilder._();
    Parser.parse(text, builder);
    if (builder._sequenceStack.length != 1) {
      throw StateError('Unbalanced procedure braces in Type 4 function');
    }
    return builder._mainSequence;
  }

  InstructionSequence get _currentSequence => _sequenceStack.last;

  @override
  void token(String text) {
    _processToken(text);
  }

  void _processToken(String token) {
    if (token == '{') {
      final child = InstructionSequence();
      _currentSequence.addProc(child);
      _sequenceStack.add(child);
      return;
    }
    if (token == '}') {
      if (_sequenceStack.length == 1) {
        throw StateError('Unexpected closing brace in Type 4 function');
      }
      _sequenceStack.removeLast();
      return;
    }
    if (_integerPattern.hasMatch(token)) {
      _currentSequence.addInteger(int.parse(token));
      return;
    }
    if (_realPattern.hasMatch(token)) {
      _currentSequence.addReal(double.parse(token));
      return;
    }
    _currentSequence.addName(token);
  }
}

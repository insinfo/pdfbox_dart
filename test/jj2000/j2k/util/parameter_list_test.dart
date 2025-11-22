import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/parameter_list.dart';
import 'package:pdfbox_dart/src/ucar/jpeg/jj2000/j2k/util/string_format_exception.dart';
import 'package:test/test.dart';

void main() {
  group('ParameterList', () {
    test('parseArgs parses boolean and values', () {
      final params = ParameterList();
      params.parseArgs(['-Ffilters', 'w5x3', '-Wlev', '5', '+Ttile']);

      expect(params.getParameter('Ffilters'), 'w5x3');
      expect(params.getParameter('Wlev'), '5');
      expect(params.getParameter('Ttile'), 'off');
      expect(params.getBooleanParameter('Ttile'), isFalse);
    });

    test('parseArgs rejects duplicate options', () {
      final params = ParameterList();
      expect(
        () => params.parseArgs(['-Aalpha', '1', '-Aalpha', '2']),
        throwsA(isA<StringFormatException>()),
      );
    });

    test('parseArgs rejects value for boolean off', () {
      final params = ParameterList();
      expect(
        () => params.parseArgs(['+Flag', 'value']),
        throwsA(isA<StringFormatException>()),
      );
    });

    test('getBooleanParameter rejects invalid value', () {
      final params = ParameterList();
      params.put('Flag', 'maybe');
      expect(
        () => params.getBooleanParameter('Flag'),
        throwsA(isA<StringFormatException>()),
      );
    });

    test('getParameter falls back to defaults', () {
      final defaults = ParameterList()..put('Shared', 'value');
      final params = ParameterList(defaults);

      expect(params.getParameter('Shared'), 'value');
    });

    test('checkListSingle accepts valid prefixed options', () {
      final params = ParameterList()
        ..put('Mfoo', '1')
        ..put('Rbar', '2');

      params.checkListSingle('M'.codeUnitAt(0), ['Mfoo']);
    });

    test('checkListSingle rejects invalid prefixed option', () {
      final params = ParameterList()..put('Mfoo', '1');

      expect(
        () => params.checkListSingle('M'.codeUnitAt(0), ['Mbar']),
        throwsArgumentError,
      );
    });

    test('checkList accepts valid options outside prefixes', () {
      final params = ParameterList()
        ..put('Xalpha', '1')
        ..put('Bbeta', '2');

      params.checkList(['Z'.codeUnitAt(0), 'Y'.codeUnitAt(0)], ['Xalpha', 'Bbeta']);
    });

    test('checkList rejects unexpected option outside prefixes', () {
      final params = ParameterList()
        ..put('Xalpha', '1')
        ..put('Bbeta', '2');

      expect(
        () => params.checkList(['Z'.codeUnitAt(0), 'Y'.codeUnitAt(0)], ['Bbeta']),
        throwsArgumentError,
      );
    });

    test('toNameArray returns first column', () {
      final info = [
        ['Aopt', 'usage', 'desc'],
        ['Bopt', 'usage', 'desc'],
      ];

      expect(ParameterList.toNameArray(info), ['Aopt', 'Bopt']);
    });
  });
}

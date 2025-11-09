import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:test/test.dart';

void main() {
  test('exposes preferred script names in order', () {
    expect(
        Language.bengali.scriptNames, orderedEquals(<String>['bng2', 'beng']));
    expect(Language.unspecified.scriptNames, isEmpty);
  });
}

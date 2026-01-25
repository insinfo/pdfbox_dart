import 'package:test/test.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xml/nodes/element.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/evaluation/context.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/exceptions/evaluation_exception.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/expressions/variable.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/types/sequence.dart';

void main() {
  test('ContextItemExpression', () {
    final node = XmlElement.tag('root');
    final context = XPathContext(node);
    const expr = ContextItemExpression();
    expect(expr(context).first, same(node));
  });
  group('VariableExpression', () {
    test('evaluate existing variable', () {
      const value = XPathSequence.single('a');
      final context = XPathContext(
        XmlElement.tag('root'),
        variables: {'var': value},
      );
      const expr = VariableExpression('var');
      expect(expr(context), same(value));
    });
    test('evaluate missing variable', () {
      final context = XPathContext(XmlElement.tag('root'));
      const expr = VariableExpression('var');
      expect(
        () => expr(context),
        throwsA(
          isA<XPathEvaluationException>().having(
            (e) => e.message,
            'message',
            'Undeclared variable "var"',
          ),
        ),
      );
    });
  });
  test('LiteralExpression', () {
    const value = XPathSequence.single('a');
    const expr = LiteralExpression(value);
    final context = XPathContext(XmlElement.tag('root'));
    expect(expr(context), same(value));
  });
}

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xml/nodes/element.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/evaluation/context.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/evaluation/expression.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/exceptions/evaluation_exception.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/expressions/function.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/types/sequence.dart';

class MockExpression extends XPathExpression {
  MockExpression(this.value);
  final XPathSequence value;
  @override
  XPathSequence call(XPathContext context) => value;
}

void main() {
  group('StaticFunctionExpression', () {
    test('evaluate', () {
      XPathSequence function(XPathContext context, List<XPathSequence> args) =>
          XPathSequence.single(args.length);
      final expr = StaticFunctionExpression(function, [
        MockExpression(XPathSequence.empty),
        MockExpression(XPathSequence.empty),
      ]);
      final context = XPathContext(XmlElement.tag('root'));
      expect(expr(context).first, 2);
    });
  });

  group('DynamicFunctionExpression', () {
    test('evaluate existing function', () {
      XPathSequence function(XPathContext context, List<XPathSequence> args) =>
          XPathSequence.single(args.length);
      final expr = DynamicFunctionExpression('fun', [
        MockExpression(XPathSequence.empty),
      ]);
      final context = XPathContext(
        XmlElement.tag('root'),
        functions: {'fun': function},
      );
      expect(expr(context).first, 1);
    });

    test('evaluate missing function', () {
      const expression = DynamicFunctionExpression('fun', []);
      final context = XPathContext(XmlElement.tag('root'));
      expect(
        () => expression(context),
        throwsA(
          isA<XPathEvaluationException>().having(
            (e) => e.message,
            'message',
            'Unknown function: fun',
          ),
        ),
      );
    });
  });
}

import 'package:test/test.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/evaluation/context.dart';
import 'package:pdfbox_dart/src/utils/xml/core/xpath/functions/notation.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';
import 'package:pdfbox_dart/src/utils/xml/xpath.dart';

final document = XmlDocument.parse('<r><a>1</a><b>2</b></r>');
final context = XPathContext(document);

void main() {
  test('op:NOTATION-equal', () {
    expect(
      opNotationEqual(context, [
        const XPathSequence.single('foo:bar'),
        const XPathSequence.single('foo:bar'),
      ]),
      [true],
    );
  });
}

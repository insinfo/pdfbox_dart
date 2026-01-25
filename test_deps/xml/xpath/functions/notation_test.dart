import 'package:test/test.dart';
import 'package:pdfbox_dart/src/dependencies/xml/src/xpath/evaluation/context.dart';
import 'package:pdfbox_dart/src/dependencies/xml/src/xpath/functions/notation.dart';
import 'package:pdfbox_dart/src/dependencies/xml/xml.dart';
import 'package:pdfbox_dart/src/dependencies/xml/xpath.dart';

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

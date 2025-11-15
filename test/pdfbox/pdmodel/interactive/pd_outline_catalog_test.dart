import 'dart:io';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_named.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_uri.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_link.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

void main() {
  test('catalog outlines load from fixture PDF', () {
    const fixturePath =
        'test/resources/pdfbox/pdmodel/interactive/outline_actions.pdf';
    final file = File(fixturePath);
    expect(file.existsSync(), isTrue,
        reason: 'Fixture outline_actions.pdf should exist for integration test');

    final document = PDDocument.loadFromBytes(file.readAsBytesSync());
    addTearDown(document.close);

    final outline = document.documentOutline;
    expect(outline, isNotNull);
    expect(outline!.open, isTrue);
    expect(outline.openCount, 3);

    final first = outline.firstChild;
    expect(first, isNotNull);
    expect(first!.title, 'Intro');
    expect(first.open, isTrue);
    expect(first.openCount, isNull);
    final destination = first.destination?.asPageDestination;
    expect(destination, isA<PDPageDestination>());
    expect((destination as PDPageDestination).page, isNotNull);

    final second = first.nextSibling;
    expect(second, isNotNull);
    expect(second!.title, 'Next Page');
    expect(second.open, isFalse);
    expect(second.openCount, -1);

    final action = second.action;
    expect(action, isA<PDActionNamed>());
    expect((action as PDActionNamed).namedAction, 'NextPage');

    final hidden = second.firstChild;
    expect(hidden, isNotNull);
    expect(hidden!.title, 'Hidden child');
    expect(hidden.destinationName, isNull);
    expect(hidden.open, isTrue);

    final third = second.nextSibling;
    expect(third, isNotNull);
    expect(third!.title, 'Example URI');
    final thirdAction = third.action;
    expect(thirdAction, isA<PDActionURI>());
    expect((thirdAction as PDActionURI).uri, 'https://example.com');

    final page = document.getPage(0);
    final annotations = page.annotations;
    expect(annotations, hasLength(3));

    final linkDest = annotations[0];
    expect(linkDest, isA<PDAnnotationLink>());
    final linkDestResolved =
        (linkDest as PDAnnotationLink).destination?.asPageDestination;
    expect(linkDestResolved, isA<PDPageDestination>());

    final linkNamed = annotations[1];
    expect(linkNamed, isA<PDAnnotationLink>());
    final linkNamedAction = (linkNamed as PDAnnotationLink).action;
    expect(linkNamedAction, isA<PDActionNamed>());
    expect((linkNamedAction as PDActionNamed).namedAction, 'NextPage');

    final linkUri = annotations[2];
    expect(linkUri, isA<PDAnnotationLink>());
    final linkUriAction = (linkUri as PDAnnotationLink).action;
    expect(linkUriAction, isA<PDActionURI>());
    expect((linkUriAction as PDActionURI).uri, 'https://example.com');
  });
}

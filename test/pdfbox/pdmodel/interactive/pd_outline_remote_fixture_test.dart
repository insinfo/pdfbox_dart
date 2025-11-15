import 'dart:io';

import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_remote_go_to.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_uri.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_link.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:test/test.dart';

void main() {
  test('mixed outline fixture covers remote actions', () {
    const fixturePath =
        'test/resources/pdfbox/pdmodel/interactive/outline_actions_remote.pdf';
    final file = File(fixturePath);
    expect(file.existsSync(), isTrue,
        reason: 'Fixture outline_actions_remote.pdf missing');

    final document = PDDocument.loadFromBytes(file.readAsBytesSync());
    addTearDown(document.close);

    final outline = document.documentOutline;
    expect(outline, isNotNull);
    expect(outline!.open, isTrue);
    expect(outline.openCount, 2);

    final first = outline.firstChild;
    expect(first, isNotNull);
    expect(first!.title, 'Remote');
    final firstAction = first.action;
    expect(firstAction, isA<PDActionRemoteGoTo>());
    final remote = firstAction as PDActionRemoteGoTo;
    expect(remote.fileName, 'remote.pdf');
    final destination = remote.destination?.asPageDestination;
    expect(destination, isA<PDPageDestination>());

    final second = first.nextSibling;
    expect(second, isNotNull);
    expect(second!.title, 'Web');
    final webAction = second.action;
    expect(webAction, isA<PDActionURI>());
    expect((webAction as PDActionURI).uri, 'https://example.org');

    final page = document.getPage(0);
    final annotations = page.annotations;
    expect(annotations, hasLength(1));
    expect(annotations.first, isA<PDAnnotationLink>());
    final annotationAction =
        (annotations.first as PDAnnotationLink).action;
    expect(annotationAction, isA<PDActionRemoteGoTo>());
  });
}

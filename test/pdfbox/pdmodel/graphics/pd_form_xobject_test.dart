import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfbox_dart/src/pdfbox/contentstream/operator/operator.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/form/pd_form_xobject.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/util/matrix.dart';
import 'package:test/test.dart';

void main() {
  group('PDFormXObject', () {
    test('parse tokens from embedded stream', () {
      final stream = PDStream.fromBytes(
        Uint8List.fromList(latin1.encode('q 1 0 0 1 0 0 cm Q')),
      );
      final form = PDFormXObject(stream);

      final tokens = form.parseContentStreamTokens();
      expect(tokens, isNotEmpty);
      expect(tokens.first, isA<Operator>());
      expect((tokens.first as Operator).name, 'q');
      expect((tokens.last as Operator).name, 'Q');
    });

    test('resources and bounding box accessors', () {
      final stream = PDStream.fromBytes(Uint8List(0));
      final form = PDFormXObject(stream);

      expect(form.resources, isNull);
      final resources = PDResources();
      form.resources = resources;
      expect(form.resources, isNotNull);

      expect(form.boundingBox, isNull);
      final rect = PDRectangle(0, 0, 100, 50);
      form.boundingBox = rect;
      expect(form.boundingBox, equals(rect));
    });

    test('matrix setter stores components', () {
      final stream = PDStream.fromBytes(Uint8List(0));
      final form = PDFormXObject(stream);

      final matrix = Matrix.fromComponents(1, 0, 0, 1, 10, 20);
      form.matrix = matrix;
      final stored = form.matrix;
      final point = stored.transformPoint(0, 0);
      expect(point.x, closeTo(10, 1e-6));
      expect(point.y, closeTo(20, 1e-6));
    });
  });
}

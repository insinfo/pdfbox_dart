import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_destination.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/action/pd_action_named.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_appearance.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_appearance_characteristics.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_factory.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_link.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_text.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_unknown.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_widget.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_border_style_dictionary.dart';
import 'package:test/test.dart';

void main() {
  group('PDAnnotationLink', () {
    test('factory resolves destination and action', () {
      final destArray = COSArray()
        ..add(COSInteger(0))
        ..add(COSName.get('Fit'));
      final actionDict = COSDictionary()
        ..setName(COSName.s, 'Named')
        ..setName(COSName.n, 'NextPage');

      final dict = COSDictionary()
        ..setName(COSName.subtype, 'Link')
        ..setItem(COSName.dest, destArray)
        ..setItem(COSName.a, actionDict)
        ..setItem(
          COSName.rect,
          COSArray()
            ..add(COSInteger(0))
            ..add(COSInteger(0))
            ..add(COSInteger(200))
            ..add(COSInteger(50)),
        );

      final annotation =
          PDAnnotationFactory.instance.createAnnotation(dict);
      expect(annotation, isA<PDAnnotationLink>());
      final link = annotation as PDAnnotationLink;
      expect(link.rect, equals(<double>[0, 0, 200, 50]));

      final destination = link.destination?.asPageDestination;
      expect(destination, isA<PDPageDestination>());
      expect((destination as PDPageDestination).pageNumber, 0);

      final action = link.action;
      expect(action, isA<PDActionNamed>());
      expect((action as PDActionNamed).namedAction, 'NextPage');

      link.destinationName = 'Chapter1';
      expect(link.destinationName, 'Chapter1');
      link.action = null;
      expect(link.action, isNull);

      final again = PDAnnotationFactory.instance.createAnnotation(dict);
      expect(identical(again, annotation), isTrue);
      expect(() => link.rect = <double>[1, 2], throwsArgumentError);
    });

    test('factory returns widget annotation for widget subtype', () {
      final dict = COSDictionary()..setName(COSName.subtype, 'Widget');
      final annotation =
          PDAnnotationFactory.instance.createAnnotation(dict);
      expect(annotation, isA<PDAnnotationWidget>());
    });
  });

  group('PDAnnotation base', () {
    test('color handles grayscale and rgb values', () {
      final annotation = PDAnnotationUnknown.fromDictionary(COSDictionary());
      expect(annotation.color, isNull);

      annotation.color = <double>[0.2];
      expect(annotation.color, equals(<double>[0.2]));
      // Removed nonexistent imports
      // import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_appearance.dart';
      // import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_factory.dart';
      // import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/annotation/pd_annotation_link.dart';
      // import 'package:test/test.dart';
      annotation.color = <double>[0.0, 0.2, 0.4, 0.6];
      expect(annotation.color, equals(<double>[0.0, 0.2, 0.4, 0.6]));

      expect(
        () => annotation.color = <double>[0.1, 0.2],
        throwsArgumentError,
      );

      annotation.color = null;
      expect(annotation.color, isNull);
    });

    test('appearance dictionaries round-trip through property accessors', () {
      final annotation = PDAnnotationUnknown.fromDictionary(COSDictionary());
      expect(annotation.appearance, isNull);

      final appearanceDictionary = PDAppearanceDictionary(COSDictionary());
      annotation.appearance = appearanceDictionary;
      final resolved = annotation.appearance;
      expect(identical(resolved, appearanceDictionary), isTrue);

      annotation.appearanceState = 'Pressed';
      expect(annotation.appearanceState, 'Pressed');

      annotation.appearance = null;
      expect(annotation.appearance, isNull);
      annotation.appearanceState = null;
      expect(annotation.appearanceState, isNull);
    });

    test('border style caches instance and clears when removed', () {
      final annotation = PDAnnotationUnknown.fromDictionary(COSDictionary());
      expect(annotation.borderStyle, isNull);

      final border = PDBorderStyleDictionary(COSDictionary())
        ..width = 1.5
        ..style = PDBorderStyleDictionary.styleSolid;

      annotation.borderStyle = border;
      expect(identical(annotation.borderStyle, border), isTrue);

      annotation.borderStyle = null;
      expect(annotation.borderStyle, isNull);
    });
  });

  group('PDAnnotationText', () {
    test('factory creates text annotation and exposes properties', () {
      final dict = COSDictionary()
        ..setName(COSName.subtype, 'Text')
        ..setBoolean(COSName.open, true)
        ..setName(COSName.nameKey, 'Comment')
        ..setString(COSName.state, 'Accepted')
        ..setString(COSName.stateModel, 'Review')
        ..setString(COSName.contents, 'Check this section');

      final annotation =
          PDAnnotationFactory.instance.createAnnotation(dict);
      expect(annotation, isA<PDAnnotationText>());
      final textAnnotation = annotation as PDAnnotationText;

      expect(textAnnotation.isOpen, isTrue);
      expect(textAnnotation.iconName, 'Comment');
      expect(textAnnotation.state, 'Accepted');
      expect(textAnnotation.stateModel, 'Review');
      expect(textAnnotation.contents, 'Check this section');

      textAnnotation.isOpen = false;
      textAnnotation.iconName = 'Key';
      textAnnotation.state = 'Rejected';
      textAnnotation.stateModel = 'Marked';
      textAnnotation.contents = 'Updated comment';

      expect(textAnnotation.isOpen, isFalse);
      expect(textAnnotation.iconName, 'Key');
      expect(textAnnotation.state, 'Rejected');
      expect(textAnnotation.stateModel, 'Marked');
      expect(textAnnotation.contents, 'Updated comment');
    });
  });

  group('PDAnnotationWidget', () {
    test('factory creates widget annotation and exposes form styling', () {
      final appearanceCharacteristicsDict = COSDictionary()
        ..setName(COSName.r, 'Rollover');
      final dict = COSDictionary()
        ..setName(COSName.subtype, 'Widget')
        ..setName(COSName.h, 'P')
        ..setString(COSName.defaultAppearance, '/Helv 12 Tf 0 g')
        ..setString(COSName.ds, 'font: 12pt Helvetica')
        ..setItem(
          COSName.appearanceCharacteristics,
          appearanceCharacteristicsDict,
        );

      final annotation =
          PDAnnotationFactory.instance.createAnnotation(dict);
      expect(annotation, isA<PDAnnotationWidget>());
      final widgetAnnotation = annotation as PDAnnotationWidget;

      expect(widgetAnnotation.highlightingMode, 'P');
      expect(widgetAnnotation.defaultAppearance, '/Helv 12 Tf 0 g');
      expect(widgetAnnotation.defaultStyle, 'font: 12pt Helvetica');
      final characteristics = widgetAnnotation.appearanceCharacteristics;
      expect(characteristics, isNotNull);
      expect(characteristics!.rolloverCaption, isNull);

      final replacement =
          PDAppearanceCharacteristicsDictionary(COSDictionary());
      widgetAnnotation.appearanceCharacteristics = replacement;
      expect(identical(widgetAnnotation.appearanceCharacteristics, replacement),
          isTrue);

      widgetAnnotation.highlightingMode = 'N';
      widgetAnnotation.defaultAppearance = '/Helv 10 Tf 1 g';
      widgetAnnotation.defaultStyle = 'font: 10pt Helvetica';
      widgetAnnotation.appearanceCharacteristics = null;

      expect(widgetAnnotation.highlightingMode, 'N');
      expect(widgetAnnotation.defaultAppearance, '/Helv 10 Tf 1 g');
      expect(widgetAnnotation.defaultStyle, 'font: 10pt Helvetica');
      expect(widgetAnnotation.appearanceCharacteristics, isNull);
    });
  });

  group('PDBorderStyleDictionary', () {
    test('width and style mutate underlying dictionary', () {
      final dictionary = COSDictionary();
      final border = PDBorderStyleDictionary(dictionary);

      expect(border.width, closeTo(1.0, 1e-8));
      border.width = 2.5;
      expect(border.width, closeTo(2.5, 1e-8));

      border.style = PDBorderStyleDictionary.styleDashed;
      expect(border.style, PDBorderStyleDictionary.styleDashed);

      border.dashPattern = <double>[3, 1];
      expect(border.dashPattern, equals(<double>[3, 1]));

      border.dashPattern = null;
      expect(border.dashPattern, isNull);

      expect(() => border.width = 0, throwsArgumentError);
      expect(() => border.dashPattern = <double>[], throwsArgumentError);
    });
  });

  group('PDAppearanceCharacteristicsDictionary', () {
    test('color helpers round-trip lists of doubles', () {
      final dictionary = COSDictionary();
      final characteristics =
          PDAppearanceCharacteristicsDictionary(dictionary);

      expect(characteristics.backgroundColor, isNull);
      characteristics.backgroundColor = <double>[1, 0.5, 0];
      expect(characteristics.backgroundColor, equals(<double>[1, 0.5, 0]));

      characteristics.borderColor = <double>[0.2, 0.3, 0.4];
      expect(characteristics.borderColor, equals(<double>[0.2, 0.3, 0.4]));

      characteristics.normalCaption = 'Sign';
      expect(characteristics.normalCaption, 'Sign');

      characteristics.rolloverCaption = 'Hover';
      expect(characteristics.rolloverCaption, 'Hover');

      characteristics.alternateCaption = 'Pressed';
      expect(characteristics.alternateCaption, 'Pressed');

      characteristics.textPosition = 2;
      expect(characteristics.textPosition, 2);

      expect(() => characteristics.textPosition = -1, throwsArgumentError);
      expect(() => characteristics.backgroundColor = <double>[],
          throwsArgumentError);
    });
  });
}


import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_rectangle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_caret.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_circle.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_file_attachment.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_free_text.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_highlight.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_ink.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_line.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_link.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_polygon.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_polyline.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_sound.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_square.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_squiggly.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_stamp.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_strike_out.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_text.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/fdf/fdf_annotation_underline.dart';
import 'package:test/test.dart';

void main() {
  group('FDFAnnotation Factory and Subtypes', () {
    test('Create unknown annotation returns null', () {
      COSDictionary dict = COSDictionary();
      dict.setName(COSName.subtype, 'UnknownType');
      expect(FDFAnnotation.create(dict), isNull);
    });

    test('Create null dictionary returns null', () {
      expect(FDFAnnotation.create(null), isNull);
    });

    test('FDFAnnotationText', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.text);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationText>());
      expect(annot!.cosObject, equals(dict));
      
      var textAnnot = annot as FDFAnnotationText;
      textAnnot.setIcon("Comment");
      expect(textAnnot.getIcon(), equals("Comment"));
    });

    test('FDFAnnotationCaret', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.caret);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationCaret>());
      
      var caretAnnot = annot as FDFAnnotationCaret;
      caretAnnot.setSymbol("paragraph");
      expect(caretAnnot.getSymbol(), equals("P"));
    });
    
    test('FDFAnnotationFreeText', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.freeText);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationFreeText>());
      
      var freeTextAnnot = annot as FDFAnnotationFreeText;
      freeTextAnnot.setDefaultAppearance("/Helv 12 Tf 0 g");
      expect(freeTextAnnot.getDefaultAppearance(), equals("/Helv 12 Tf 0 g"));
    });

    test('FDFAnnotationFileAttachment', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.fileAttachment);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationFileAttachment>());
    });

    test('FDFAnnotationHighlight', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.highlight);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationHighlight>());
    });

    test('FDFAnnotationInk', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.ink);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationInk>());
      
      var inkAnnot = annot as FDFAnnotationInk;
      inkAnnot.setInkList([[1.0, 2.0, 3.0, 4.0]]);
      expect(inkAnnot.getInkList(), isNotNull);
      expect(inkAnnot.getInkList()!.length, equals(1));
    });

    test('FDFAnnotationLine', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.line);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationLine>());
      
      var lineAnnot = annot as FDFAnnotationLine;
      lineAnnot.setLine([10, 10, 100, 100]);
      expect(lineAnnot.getLine(), equals([10.0, 10.0, 100.0, 100.0]));
    });

    test('FDFAnnotationLink', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.link);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationLink>());
    });

    test('FDFAnnotationCircle', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.circle);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationCircle>());
      
      var circleAnnot = annot as FDFAnnotationCircle;
      circleAnnot.setInteriorColor([0.5, 0.5, 0.5]);
      expect(circleAnnot.getInteriorColor(), equals([0.5, 0.5, 0.5]));
    });

    test('FDFAnnotationSquare', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.square);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationSquare>());
      
      var squareAnnot = annot as FDFAnnotationSquare;
      PDRectangle rect = PDRectangle(0, 0, 10, 10);
      squareAnnot.setFringe(rect);
      expect(squareAnnot.getFringe()?.toCOSArray().toList(), equals(rect.toCOSArray().toList()));
    });

    test('FDFAnnotationPolygon', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.polygon);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationPolygon>());
      
      var polygonAnnot = annot as FDFAnnotationPolygon;
      polygonAnnot.setVertices([10, 10, 20, 20, 30, 10]);
      expect(polygonAnnot.getVertices(), equals([10.0, 10.0, 20.0, 20.0, 30.0, 10.0]));
    });

    test('FDFAnnotationPolyline', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.polyline);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationPolyline>());
      
      var polylineAnnot = annot as FDFAnnotationPolyline;
      polylineAnnot.setVertices([10, 10, 20, 20]);
      expect(polylineAnnot.getVertices(), equals([10.0, 10.0, 20.0, 20.0]));
    });

    test('FDFAnnotationSound', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.sound);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationSound>());
    });

    test('FDFAnnotationSquiggly', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.squiggly);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationSquiggly>());
    });

    test('FDFAnnotationStamp', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.stamp);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationStamp>());
    });

    test('FDFAnnotationStrikeOut', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.strikeOut);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationStrikeOut>());
    });

    test('FDFAnnotationUnderline', () {
      COSDictionary dict = COSDictionary();
      dict.setItem(COSName.subtype, COSName.underline);
      FDFAnnotation? annot = FDFAnnotation.create(dict);
      expect(annot, isA<FDFAnnotationUnderline>());
    });
    
    test('FDFAnnotation Common Properties', () {
      var annot = FDFAnnotationText();
      
      // Page
      annot.setPage(5);
      expect(annot.getPage(), equals(5));
      
      // Color
      annot.setColor([1.0, 0.0, 0.0]);
      expect(annot.getColor(), equals([1.0, 0.0, 0.0]));
      annot.setColor(null);
      expect(annot.getColor(), isNull);
      
      // Date
      annot.setDate("D:20230101");
      expect(annot.getDate(), equals("D:20230101"));
      
      // Flags
      annot.setInvisible(true);
      expect(annot.isInvisible(), isTrue);
      
      annot.setHidden(true);
      expect(annot.isHidden(), isTrue);
      
      // Name
      annot.setName("MyAnnotation");
      expect(annot.getName(), equals("MyAnnotation"));
      
      // Rectangle
      PDRectangle rect = PDRectangle(10, 10, 100, 100);
      annot.setRectangle(rect);
      expect(annot.getRectangle()?.toCOSArray().toList(), equals(rect.toCOSArray().toList()));
      
      // Contents
      annot.setContents("Content string");
      expect(annot.getContents(), equals("Content string"));
      
      // Title
      annot.setTitle("My Title");
      expect(annot.getTitle(), equals("My Title"));
      
      // Opacity
      annot.setOpacity(0.5);
      expect(annot.getOpacity(), equals(0.5));
      
      // Subject
      annot.setSubject("My Subject");
      expect(annot.getSubject(), equals("My Subject"));
    });
  });
}


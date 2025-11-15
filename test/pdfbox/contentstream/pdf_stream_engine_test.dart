import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/contentstream/pdf_stream_engine.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_string.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_resources.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_stream.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/pdxobject.dart';

void main() {
  group('PDFStreamEngine', () {
    late RecordingPDFStreamEngine engine;
    late PDResources resources;

    setUp(() {
      engine = RecordingPDFStreamEngine();
      resources = PDResources();
      resources.registerStandard14Font(COSName('F1'), 'Helvetica');
    });

    test('processes basic text operators', () {
      final page = _pageWithContent('BT /F1 12 Tf 10 20 Td (Hi) Tj ET', resources);
      engine.processPage(page);

      expect(
        engine.events,
        <String>['BT', 'Tf:F1:12.0', 'Td:10.0:20.0', 'Tj:Hi', 'ET'],
      );
    });

    test('concatenates matrices from cm operator', () {
      final page = _pageWithContent('1 0 0 1 5 5 cm', resources);
      engine.processPage(page);

      expect(engine.events, contains('cm:1.0:0.0:0.0:1.0:5.0:5.0'));
    });

    test('invokes image XObjects via Do', () {
      final imageResources = _resourcesWithImage();
      final page = _pageWithContent('q /Im1 Do Q', imageResources);
      engine.processPage(page);

      expect(engine.events, contains('Do:Im1'));
    });

    test('records path and color operators', () {
      final page = _pageWithContent('0.1 0.2 0.3 rg 0 0 m 10 10 l S', resources);
      engine.processPage(page);

      expect(engine.events, contains('rg:0.1:0.2:0.3'));
      expect(engine.events, contains('m:0.0:0.0'));
      expect(engine.events, contains('l:10.0:10.0'));
      expect(engine.events, contains('S:false'));
    });

    test('handles marked content operators', () {
      final content =
          '/Span BMC /Span << /ActualText (Hi) >> BDC /Artifact MP /Artifact << /Type /Pagination >> DP EMC';
      final page = _pageWithContent(content, resources);
      engine.processPage(page);

      expect(engine.events, contains('BMC:Span'));
      expect(engine.events, contains('BDC:Span'));
      expect(engine.events, contains('MP:Artifact'));
      expect(engine.events, contains('DP:Artifact'));
      expect(engine.events, contains('EMC'));
    });

    test('processes shading fill operator', () {
      final shadingResources = _resourcesWithShading();
      final page = _pageWithContent('/Sh1 sh', shadingResources);
      engine.processPage(page);

      expect(engine.events, contains('sh:Sh1'));
    });

    test('applies extended graphics state from gs operator', () {
      final gsResources = _resourcesWithExtGState();
      final page = _pageWithContent('q /GS1 gs Q', gsResources);
      engine.processPage(page);

      expect(engine.events, contains('gs:GS1:2.0'));
    });

    test('records Type3 glyph metrics operators', () {
      final page = _pageWithContent('1 0 d0 2 0 0 2 0 0 d1', resources);
      engine.processPage(page);

      expect(engine.events, contains('d0:1.0:0.0'));
      expect(engine.events, contains('d1:2.0:0.0:0.0:2.0:0.0:0.0'));
    });

    test('handles text state operators', () {
      const content =
          "BT /F1 12 Tf 20 TL 120 Tw 5 Tc 90 Tz 2 Tr 3 Ts (First) Tj ' (Second) 30 40 \" (Third) ET";
      final page = _pageWithContent(content, resources);
      engine.processPage(page);

      expect(engine.events, contains('TL:20.0'));
      expect(engine.events, contains('Tw:120.0'));
      expect(engine.events, contains('Tc:5.0'));
      expect(engine.events, contains('Tz:90.0'));
      expect(engine.events, contains('Tr:2'));
      expect(engine.events, contains('Ts:3.0'));
      expect(engine.events, contains('Tj:First'));
      expect(engine.events.where((event) => event == 'T*').length, greaterThanOrEqualTo(2));
      expect(engine.events, contains("':Second"));
      expect(engine.events, contains('":30.0:40.0:Third'));
      expect(engine.events, contains('Tj:Third'));
    });
  });
}

PDPage _pageWithContent(String content, PDResources resources) {
  final page = PDPage();
  page.resources = resources;
  final bytes = Uint8List.fromList(ascii.encode('$content\n'));
  page.setContentStream(PDStream.fromBytes(bytes));
  return page;
}

PDResources _resourcesWithImage() {
  final resources = PDResources();
  final imageStream = COSStream()
    ..setName(COSName.type, COSName.xObject.name)
    ..setName(COSName.subtype, COSName.image.name)
    ..setName(COSName.colorSpace, COSName.deviceGray.name)
    ..setInt(COSName.width, 1)
    ..setInt(COSName.height, 1)
    ..setInt(COSName.bitsPerComponent, 1)
    ..data = Uint8List.fromList(const <int>[0]);

  final xObjects = COSDictionary();
  xObjects[COSName('Im1')] = imageStream;
  resources.cosObject[COSName.xObject] = xObjects;
  return resources;
}

PDResources _resourcesWithShading() {
  final resources = PDResources();
  final shading = COSDictionary()
    ..setInt(COSName.shadingType, 2)
    ..setName(COSName.colorSpace, COSName.deviceGray.name);
  final shadings = COSDictionary();
  shadings[COSName('Sh1')] = shading;
  resources.cosObject[COSName.shading] = shadings;
  return resources;
}

PDResources _resourcesWithExtGState() {
  final resources = PDResources();
  final gs = COSDictionary()..setFloat(COSName.lw, 2);
  final states = COSDictionary();
  states[COSName('GS1')] = gs;
  resources.cosObject[COSName.extGState] = states;
  return resources;
}

class RecordingPDFStreamEngine extends PDFStreamEngine {
  final List<String> events = <String>[];

  @override
  void beginText() {
    super.beginText();
    events.add('BT');
  }

  @override
  void endText() {
    events.add('ET');
  }

  @override
  void setFont(COSName fontName, double fontSize) {
    super.setFont(fontName, fontSize);
    events.add('Tf:${fontName.name}:${fontSize.toString()}');
  }

  @override
  void moveText(double tx, double ty) {
    super.moveText(tx, ty);
    events.add('Td:${tx.toString()}:${ty.toString()}');
  }

  @override
  void setTextLeading(double leading) {
    super.setTextLeading(leading);
    events.add('TL:${leading.toString()}');
  }

  @override
  void setCharacterSpacing(double spacing) {
    super.setCharacterSpacing(spacing);
    events.add('Tc:${spacing.toString()}');
  }

  @override
  void setWordSpacing(double spacing) {
    super.setWordSpacing(spacing);
    events.add('Tw:${spacing.toString()}');
  }

  @override
  void setHorizontalScaling(double scale) {
    super.setHorizontalScaling(scale);
    events.add('Tz:${scale.toString()}');
  }

  @override
  void setTextRenderingMode(int mode) {
    super.setTextRenderingMode(mode);
    events.add('Tr:${mode.toString()}');
  }

  @override
  void setTextRise(double rise) {
    super.setTextRise(rise);
    events.add('Ts:${rise.toString()}');
  }

  @override
  void showTextString(COSString text) {
    events.add('Tj:${text.string}');
  }

  @override
  void nextLine() {
    super.nextLine();
    events.add('T*');
  }

  @override
  void showTextLine(COSString text) {
    super.showTextLine(text);
    events.add("':${text.string}");
  }

  @override
  void showTextLineAndSpacing(
      double wordSpacing, double characterSpacing, COSString text) {
    super.showTextLineAndSpacing(wordSpacing, characterSpacing, text);
    events.add('":${wordSpacing.toString()}:${characterSpacing.toString()}:${text.string}');
  }

  @override
  void concatenateMatrix(
      double a, double b, double c, double d, double e, double f) {
    super.concatenateMatrix(a, b, c, d, e, f);
    events.add('cm:$a:$b:$c:$d:$e:$f');
  }

  @override
  void processImageXObject(COSName name, PDImageXObject image) {
    events.add('Do:${name.name}');
  }

  @override
  void setNonStrokingRGB(double r, double g, double b) {
    super.setNonStrokingRGB(r, g, b);
    events.add('rg:$r:$g:$b');
  }

  @override
  void moveTo(double x, double y) {
    events.add('m:$x:$y');
  }

  @override
  void lineTo(double x, double y) {
    events.add('l:$x:$y');
  }

  @override
  void strokePath({bool close = false}) {
    events.add('S:$close');
  }

  @override
  void beginMarkedContentSequence(COSName tag, COSDictionary? properties) {
    final kind = properties == null ? 'BMC' : 'BDC';
    events.add('$kind:${tag.name}');
  }

  @override
  void endMarkedContentSequence() {
    events.add('EMC');
  }

  @override
  void markedContentPoint(COSName tag, COSDictionary? properties) {
    final kind = properties == null ? 'MP' : 'DP';
    events.add('$kind:${tag.name}');
  }

  @override
  void shadingFill(COSName resourceName) {
    super.shadingFill(resourceName);
    events.add('sh:${resourceName.name}');
  }

  @override
  void setGraphicsStateParameters(COSName dictionaryName) {
    super.setGraphicsStateParameters(dictionaryName);
    final width = currentGraphicsState?.lineWidth;
    events.add('gs:${dictionaryName.name}:${width ?? 'null'}');
  }

  @override
  void setType3GlyphWidth(double wx, double wy) {
    super.setType3GlyphWidth(wx, wy);
    events.add('d0:$wx:$wy');
  }

  @override
  void setType3GlyphWidthAndBoundingBox(
    double wx,
    double wy,
    double llx,
    double lly,
    double urx,
    double ury,
  ) {
    super.setType3GlyphWidthAndBoundingBox(wx, wy, llx, lly, urx, ury);
    events.add('d1:$wx:$wy:$llx:$lly:$urx:$ury');
  }
}

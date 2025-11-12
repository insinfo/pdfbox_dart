import 'dart:convert';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_metadata.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_label_range.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_page_labels.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/markedcontent/pd_property_list.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/graphics/optionalcontent/pd_optional_content_properties.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/viewerpreferences/pd_viewer_preferences.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/page_layout.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/page_mode.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document_information.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:test/test.dart';

void main() {
  group('PDDocumentCatalog', () {
    test('page labels round-trip via catalog', () {
      final document = PDDocument();
      document.addPage(PDPage());
      document.addPage(PDPage());

      final labels = PDPageLabels(document);
      final range = PDPageLabelRange()
        ..style = PDPageLabelRange.styleRomanUpper;
      labels.setLabelItem(0, range);

      final catalog = document.documentCatalog;
      catalog.pageLabels = labels;

      final retrieved = catalog.pageLabels;
      expect(retrieved, isNotNull);
      final formatted = retrieved!.getLabelsByPageIndices();
      expect(formatted, hasLength(2));
      expect(formatted[0], 'I');
      expect(formatted[1], 'II');
    });

    test('optional content properties stored and retrieved', () {
      final document = PDDocument();
      final catalog = document.documentCatalog;

      final ocProps = PDOptionalContentProperties();
      final group = PDOptionalContentGroup('Layer 1');
      ocProps.addGroup(group);
      catalog.optionalContentProperties = ocProps;

      final roundTrip = catalog.optionalContentProperties;
      expect(roundTrip, isNotNull);
      expect(roundTrip!.getGroup('Layer 1')?.name, 'Layer 1');
    });

    test('metadata round-trip', () {
      final document = PDDocument();
      final catalog = document.documentCatalog;
      final xml = utf8.encode('<x:xmpmeta></x:xmpmeta>');
      final metadata = PDMetadata.fromBytes(document, xml);

      catalog.metadata = metadata;
      final roundTrip = catalog.metadata;
      expect(roundTrip, isNotNull);
      expect(
        utf8.decode(roundTrip!.exportXMPMetadata() ?? <int>[]),
        '<x:xmpmeta></x:xmpmeta>',
      );
    });

    test('page layout and mode persisted', () {
      final document = PDDocument();
      final catalog = document.documentCatalog;

      catalog.pageLayout = PageLayout.twoPageRight;
      catalog.pageMode = PageMode.fullScreen;

      expect(catalog.pageLayout, PageLayout.twoPageRight);
      expect(catalog.pageMode, PageMode.fullScreen);
      expect(catalog.cosObject.getNameAsString(COSName.pageLayout), 'TwoPageRight');
      expect(catalog.cosObject.getNameAsString(COSName.pageMode), 'FullScreen');
    });

    test('viewer preferences round-trip', () {
      final document = PDDocument();
      final catalog = document.documentCatalog;

      expect(catalog.viewerPreferences, isNull);

      final preferences = PDViewerPreferences()
        ..hideToolbar = true
        ..direction = ReadingDirection.r2l
        ..printScaling = PrintScaling.none;

      catalog.viewerPreferences = preferences;

      final stored = catalog.cosObject.getCOSDictionary(COSName.viewerPreferences);
      expect(stored, isNotNull);
      expect(stored!.getBoolean(COSName.hideToolbar), isTrue);
      expect(stored.getNameAsString(COSName.direction), 'R2L');

      final roundTrip = catalog.viewerPreferences;
      expect(roundTrip, isNotNull);
      expect(roundTrip!.hideToolbar, isTrue);
      expect(roundTrip.direction, ReadingDirection.r2l);
      expect(roundTrip.printScaling, PrintScaling.none);

      catalog.viewerPreferences = null;
      expect(catalog.cosObject.getDictionaryObject(COSName.viewerPreferences), isNull);
    });
  });

  test('document information updates trailer', () {
    final document = PDDocument();
    final info = document.documentInformation;
    info.title = 'Example';
    info.author = 'Author';

    final trailerInfo = document.cosDocument.trailer.getCOSDictionary(COSName.info);
    expect(trailerInfo, isNotNull);
    expect(trailerInfo!.getString(COSName.title), 'Example');
    expect(trailerInfo.getString(COSName.author), 'Author');

    final replacement = PDDocumentInformation()
      ..producer = 'pdfbox_dart';
    document.documentInformation = replacement;

    final updated = document.cosDocument.trailer.getCOSDictionary(COSName.info);
    expect(updated, isNotNull);
    expect(updated!.getString(COSName.producer), 'pdfbox_dart');
  });
}

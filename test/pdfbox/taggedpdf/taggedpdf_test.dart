import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_base.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_float.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_integer.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_attribute_object.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_mark_info.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_structure_element.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_structure_tree_root.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/taggedpdf/pd_artifact_marked_content.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/taggedpdf/pd_layout_attribute_object.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/taggedpdf/pd_list_attribute_object.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/taggedpdf/pd_table_attribute_object.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_number_tree_node.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_parent_tree_value.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_structure_element_name_tree_node.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_null.dart';

void main() {
  test('PDMarkInfo: toggles flags via COSDictionary', () {
    final markInfo = PDMarkInfo();

    expect(markInfo.isMarked, isFalse);
    expect(markInfo.usesUserProperties, isFalse);
    expect(markInfo.isSuspect, isFalse);

    markInfo.isMarked = true;
    markInfo.usesUserProperties = true;
    markInfo.isSuspect = true;

    expect(markInfo.isMarked, isTrue);
    expect(markInfo.usesUserProperties, isTrue);
    expect(markInfo.isSuspect, isTrue);
  });

  test('PDArtifactMarkedContent: reads bbox and attachment edges', () {
    final props = COSDictionary();
    props[COSName.type] = COSName.getPDFName('Pagination');
    props[COSName.subtype] = COSName.getPDFName('Header');

    final bbox = COSArray(<COSBase>[
      COSFloat(10),
      COSFloat(20),
      COSFloat(110),
      COSFloat(70),
    ]);
    props[COSName.bBox] = bbox;

    final attached = COSArray(<COSBase>[
      COSName.getPDFName('Top'),
      COSName.getPDFName('Left'),
    ]);
    props[COSName.attached] = attached;

    final artifact = PDArtifactMarkedContent(props);
    expect(artifact.type, 'Pagination');
    expect(artifact.subtype, 'Header');

    final rect = artifact.bbox;
    expect(rect, isNotNull);
    expect(rect!.lowerLeftX, 10);
    expect(rect.lowerLeftY, 20);
    expect(rect.upperRightX, 110);
    expect(rect.upperRightY, 70);

    expect(artifact.isTopAttached, isTrue);
    expect(artifact.isLeftAttached, isTrue);
    expect(artifact.isBottomAttached, isFalse);
    expect(artifact.isRightAttached, isFalse);
  });

  test('PDAttributeObject.create: instantiates correct attribute objects', () {
    COSDictionary dictWithOwner(String owner) {
      final d = COSDictionary();
      d.setName(COSName.o, owner);
      return d;
    }

    expect(
      PDAttributeObject.create(dictWithOwner(PDListAttributeObject.ownerList)),
      isA<PDListAttributeObject>(),
    );
    expect(
      PDAttributeObject.create(dictWithOwner(PDLayoutAttributeObject.ownerLayout)),
      isA<PDLayoutAttributeObject>(),
    );
    expect(
      PDAttributeObject.create(dictWithOwner(PDTableAttributeObject.ownerTable)),
      isA<PDTableAttributeObject>(),
    );

    // Unknown owners fall back to PDDefaultAttributeObject.
    final unknown = dictWithOwner('MadeUpOwner');
    final created = PDAttributeObject.create(unknown);
    expect(created.runtimeType.toString(), contains('PDDefaultAttributeObject'));
  });

  test('PDStructureElement: attribute changes bump revision association', () {
    final root = PDStructureTreeRoot();
    final element = PDStructureElement.create('P', root);

    final attr = PDListAttributeObject();
    element.addAttribute(attr);

    // addAttribute writes revisionNumber at insertion time.
    final baseA1 = element.cosObject.getDictionaryObject(COSName.a);
    expect(baseA1, isA<COSArray>());
    final array1 = baseA1 as COSArray;
    expect(array1.length, 2);
    expect(array1.getObject(1), isA<COSInteger>());
    expect((array1.getObject(1) as COSInteger).intValue, 0);

    element.incrementRevisionNumber();

    // This setter should notify the structure element and update the revision integer.
    attr.listNumbering = PDListAttributeObject.listNumberingDecimal;

    final baseA2 = element.cosObject.getDictionaryObject(COSName.a);
    expect(baseA2, isA<COSArray>());
    final array2 = baseA2 as COSArray;
    expect(array2.length, 2);
    expect((array2.getObject(1) as COSInteger).intValue, 1);
  });

  test('PDStructureTreeRoot: ParentTree and ParentTreeNextKey roundtrip', () {
    final root = PDStructureTreeRoot();

    final parentTree = PDNumberTreeNode<PDParentTreeValue>(
      valueFactory: (base) => PDParentTreeValue(base),
    );
    parentTree.setNumbers(<int, PDParentTreeValue?>{
      0: PDParentTreeValue(COSName.getPDFName('K0')),
      10: PDParentTreeValue(COSInteger(123)),
    });

    root.setParentTree(parentTree);
    root.setParentTreeNextKey(42);

    final roundtripTree = root.getParentTree();
    expect(roundtripTree, isNotNull);
    expect(roundtripTree!.getValue(0)?.cosObject, isA<COSName>());
    expect((roundtripTree.getValue(10)?.cosObject as COSInteger).intValue, 123);

    expect(root.getParentTreeNextKey(), 42);
  });

  test('PDStructureTreeRoot: IDTree maps IDs to structure elements', () {
    final root = PDStructureTreeRoot();
    final idTree = PDStructureElementNameTreeNode();

    final element = PDStructureElement.create('P', root);
    idTree.setNames(<String, PDStructureElement?>{'id-1': element});

    root.setIDTree(idTree);

    final fetchedTree = root.getIDTree();
    expect(fetchedTree, isNotNull);
    final fetched = fetchedTree!.getValue('id-1');
    expect(fetched, isNotNull);
    expect(fetched!.getStructureType(), 'P');
  });

  test('PDDocumentCatalog: exposes MarkInfo and StructTreeRoot', () {
    final doc = PDDocument();
    try {
      final catalog = doc.documentCatalog;

      final markInfo = PDMarkInfo()..isMarked = true;
      catalog.markInfo = markInfo;
      expect(catalog.markInfo, isNotNull);
      expect(catalog.markInfo!.isMarked, isTrue);

      final treeRoot = PDStructureTreeRoot();
      catalog.structureTreeRoot = treeRoot;
      expect(catalog.structureTreeRoot, isNotNull);
      expect(catalog.structureTreeRoot!.getType(), PDStructureTreeRoot.TYPE);
    } finally {
      doc.close();
    }
  });

  test('PDStructureElement: Pg/ID/Lang/Alt/ActualText roundtrip', () {
    final doc = PDDocument();
    try {
      final page = PDPage();
      doc.addPage(page);

      final root = PDStructureTreeRoot();
      final element = PDStructureElement.create('Span', root);

      element.setPage(page);
      element.setId('elem-1');
      element.setLanguage('pt-BR');
      element.setAlternateDescription('Imagem decorativa');
      element.setActualText('Texto substituto');

      expect(element.getPage(), isNotNull);
      expect(element.getId(), 'elem-1');
      expect(element.getLanguage(), 'pt-BR');
      expect(element.getAlternateDescription(), 'Imagem decorativa');
      expect(element.getActualText(), 'Texto substituto');
    } finally {
      doc.close();
    }
  });

  test('PDParentTreeValue: supports MCID-indexed arrays', () {
    final root = PDStructureTreeRoot();
    final e1 = PDStructureElement.create('P', root);
    final e2 = PDStructureElement.create('Span', root);

    // MCID 0 => null, MCID 1 => e1, MCID 2 => e2
    final arr = COSArray(<COSBase>[COSNull.instance, e1.cosObject, e2.cosObject]);
    final value = PDParentTreeValue.fromArray(arr);

    expect(value.getAtMcid(0), isNull);
    final at1 = value.getAtMcid(1);
    expect(at1, isA<PDStructureElement>());
    expect((at1 as PDStructureElement).getStructureType(), 'P');

    final at2 = value.getAtMcid(2);
    expect(at2, isA<PDStructureElement>());
    expect((at2 as PDStructureElement).getStructureType(), 'Span');
  });
}


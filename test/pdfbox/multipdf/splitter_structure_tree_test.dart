import 'package:test/test.dart';

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_base.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_dictionary.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_object.dart';
import 'package:pdfbox_dart/src/pdfbox/multipdf/splitter.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_document.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/pd_page.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/common/pd_number_tree_node.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_parent_tree_value.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_structure_element.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/documentinterchange/logicalstructure/pd_structure_tree_root.dart';

void main() {
  group('Splitter', () {
    test('cloneStructureTree keeps ParentTree entries for split pages', () {
      final doc = PDDocument();
      final page = PDPage();
      doc.addPage(page);
      page.structParents = 0;

      final structTreeRoot = PDStructureTreeRoot();
      doc.documentCatalog.structureTreeRoot = structTreeRoot;

      final element = PDStructureElement.create('P', structTreeRoot);
      element.setPage(page);
      structTreeRoot.appendKid(element);

      final parentTreeArray = COSArray()..addObject(element.cosObject);
      final parentTree = PDNumberTreeNode<PDParentTreeValue>(
          valueFactory: (base) => PDParentTreeValue(base));
      parentTree.setNumbers({0: PDParentTreeValue.fromArray(parentTreeArray)});
      structTreeRoot.setParentTree(parentTree);
      structTreeRoot.setParentTreeNextKey(1);

      final splitter = Splitter();
      final docs = splitter.split(doc);

      expect(docs, hasLength(1));
      final splitDoc = docs.first;
      final splitRoot = splitDoc.documentCatalog.structureTreeRoot;
      expect(splitRoot, isNotNull);

      final splitParentTree = splitRoot!.getParentTree();
      expect(splitParentTree, isNotNull);

      final numbers = splitParentTree!.numbers;
      expect(numbers, isNotNull);
      expect(numbers!.containsKey(0), isTrue);

      final value = numbers[0];
      expect(value, isNotNull);
      final array = value!.array;
      expect(array, isNotNull);
      expect(array!.length, 1);

      final kidDict = _asDictionary(array.getObject(0));
      expect(kidDict, isNotNull);

      final splitPage = splitDoc.getPage(0);
      final pgDict = kidDict!.getDictionaryObject(COSName.pg);
      expect(pgDict is COSDictionary, isTrue);
      expect(identical(pgDict, splitPage.cosObject), isTrue);

      splitDoc.close();
      doc.close();
    });
  });
}

COSDictionary? _asDictionary(COSBase? value) {
  if (value is COSDictionary) {
    return value;
  }
  if (value is COSObject && value.object is COSDictionary) {
    return value.object as COSDictionary;
  }
  return null;
}


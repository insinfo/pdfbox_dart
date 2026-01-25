import 'dart:math';

import 'package:logging/logging.dart';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';

import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_document_information.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/pd_page_tree.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/common/pd_number_tree_node.dart';
import '../pdmodel/interactive/annotation/pd_annotation.dart';
import '../pdmodel/interactive/annotation/pd_annotation_factory.dart';
import 'pdf_clone_utility.dart';
import '../pdmodel/interactive/annotation/pd_annotation_link.dart';
import '../pdmodel/interactive/annotation/pd_annotation_widget.dart';
import '../pdmodel/interactive/action/pd_action_go_to.dart';
import '../pdmodel/interactive/action/pd_action.dart';
import '../pdmodel/interactive/action/pd_action_factory.dart';
import '../pdmodel/common/pd_page_destination.dart';
import '../pdmodel/common/pd_destination.dart';
import '../cos/cos_object.dart';
import '../pdmodel/documentinterchange/logicalstructure/pd_parent_tree_value.dart';
import '../pdmodel/documentinterchange/logicalstructure/pd_structure_element.dart';
import '../pdmodel/documentinterchange/logicalstructure/pd_structure_tree_root.dart';
import '../pdmodel/graphics/form/pd_form_xobject.dart';
import '../pdmodel/graphics/pdxobject.dart';
import '../pdmodel/pd_structure_element_name_tree_node.dart';

/// Split a document into several other documents.
class Splitter {
  static final Logger _logger = Logger('pdfbox.Splitter');

  PDDocument? _sourceDocument;
  PDDocument? _currentDestinationDocument;

  int _splitLength = 1;
  int _startPage = -2147483648; // Integer.MIN_VALUE
  int _endPage = 2147483647; // Integer.MAX_VALUE
  List<PDDocument>? _destinationDocuments;
  Map<COSDictionary, COSDictionary>? _pageDictMap;
  List<Map<COSDictionary, COSDictionary>>? _pageDictMaps;
  Map<COSDictionary, COSDictionary>? _annotDictMap;
  List<Map<COSDictionary, COSDictionary>>? _annotDictMaps;
  Map<PDPageDestination, COSDictionary>? _destToFixMap;
  List<Map<PDPageDestination, COSDictionary>>? _destToFixMaps;
  Map<COSDictionary, COSDictionary>? _structDictMap;
  Set<String>? _idSet;
  Set<COSName>? _roleSet;

  int _currentPageNumber = 0;

  /// This will take a document and split into several other documents.
  ///
  /// [document] The document to split.
  ///
  /// Returns a list of all the split documents. These should all be saved before closing any
  /// documents, including the source document. Any further operations should be made after
  /// reloading them, to avoid problems due to resource sharing. For the same reason, they should
  /// not be saved with encryption.
  List<PDDocument> split(PDDocument document) {
    // reset the currentPageNumber for a case if the split method will be used several times
    _currentPageNumber = 0;
    _destinationDocuments = <PDDocument>[];
    _sourceDocument = document;
    _pageDictMaps = <Map<COSDictionary, COSDictionary>>[];
    _annotDictMaps = <Map<COSDictionary, COSDictionary>>[];
    _destToFixMaps = <Map<PDPageDestination, COSDictionary>>[];

    _processPages();

    for (var i = 0; i < _destinationDocuments!.length; i++) {
      final destinationDocument = _destinationDocuments![i];
      _pageDictMap = _pageDictMaps![i];
      _annotDictMap = _annotDictMaps![i];
      _destToFixMap = _destToFixMaps![i];
      _cloneStructureTree(destinationDocument);
      _fixDestinations(destinationDocument);
    }

    return _destinationDocuments!;
  }

  /// This will tell the splitting algorithm where to split the pages.  The default
  /// is 1, so every page will become a new document.  If it was two then each document would
  /// contain 2 pages.  If the source document had 5 pages it would split into
  /// 3 new documents, 2 documents containing 2 pages and 1 document containing one
  /// page.
  ///
  /// [split] The number of pages each split document should contain.
  void setSplitAtPage(int split) {
    if (split <= 0) {
      throw ArgumentError("Number of pages is smaller than one");
    }
    _splitLength = split;
  }

  /// This will set the start page.
  ///
  /// [start] the 1-based start page
  void setStartPage(int start) {
    if (start <= 0) {
      throw ArgumentError("Start page is smaller than one");
    }
    _startPage = start;
  }

  /// This will set the end page.
  ///
  /// [end] the 1-based end page
  void setEndPage(int end) {
    if (end <= 0) {
      throw ArgumentError("End page is smaller than one");
    }
    if (end < _startPage) {
      throw ArgumentError("End page is smaller than startPage");
    }
    _endPage = end;
  }

  void _processPages() {
    for (int i = 0; i < _sourceDocument!.numberOfPages; i++) {
      final page = _sourceDocument!.getPage(i);
      if (_currentPageNumber + 1 >= _startPage && _currentPageNumber + 1 <= _endPage) {
        _processPage(page);
        _currentPageNumber++;
      } else {
        if (_currentPageNumber > _endPage) {
          break;
        } else {
          _currentPageNumber++;
        }
      }
    }
  }

  void _createNewDocumentIfNecessary() {
    if (splitAtPage(_currentPageNumber) || _currentDestinationDocument == null) {
      _currentDestinationDocument = createNewDocument();
      _destinationDocuments!.add(_currentDestinationDocument!);
      _pageDictMap = <COSDictionary, COSDictionary>{};
      _pageDictMaps!.add(_pageDictMap!);
      _annotDictMap = <COSDictionary, COSDictionary>{};
      _annotDictMaps!.add(_annotDictMap!);
      _destToFixMap = <PDPageDestination, COSDictionary>{};
      _destToFixMaps!.add(_destToFixMap!);
    }
  }

  /// Check if it is necessary to create a new document.
  /// By default a split occurs at every page.
  bool splitAtPage(int pageNumber) {
    return (pageNumber + 1 - max(1, _startPage)) % _splitLength == 0;
  }

  /// Create a new document to write the split contents to.
  PDDocument createNewDocument() {
    final document = PDDocument();
    document.version = _sourceDocument!.version;
    final sourceDocumentInformation = _sourceDocument!.documentInformation;
    
    // PDFBOX-5317: Image Capture Plus files where /Root and /Info share the same dictionary
    // Only copy simple elements to avoid huge files
    final sourceDocumentInformationDictionary = sourceDocumentInformation.cosObject;
    final destDocumentInformationDictionary = COSDictionary();
    
    for (final entry in sourceDocumentInformationDictionary.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (value is COSDictionary) {
        _logger.warning("Nested entry for key '${key.name}' skipped in document information dictionary");
        if (_sourceDocument!.documentCatalog.cosObject == _sourceDocument!.documentInformation.cosObject) {
           _logger.warning("/Root and /Info share the same dictionary");
        }
        continue;
      }
      if (COSName.type == key) {
        continue; // there is no /Type in the document information dictionary
      }
      destDocumentInformationDictionary[key] = value;
    }
    document.documentInformation = PDDocumentInformation(dictionary: destDocumentInformationDictionary);
    
    final destCatalog = document.documentCatalog;
    final sourceCatalog = _sourceDocument!.documentCatalog;
    
    destCatalog.viewerPreferences = sourceCatalog.viewerPreferences;
    destCatalog.language = sourceCatalog.language;
    destCatalog.metadata = sourceCatalog.metadata;
    
    destCatalog.markInfo = sourceCatalog.markInfo;
    
    return document;
  }

  /// Interface to start processing a new page.
  void _processPage(PDPage page) {
    _createNewDocumentIfNecessary();

    final imported = _importPage(_currentDestinationDocument!, page);
    
    if (page.resources.cosObject.isNotEmpty && !page.cosObject.containsKey(COSName.resources)) {
       imported.resources = page.resources;
       _logger.info("Resources imported in Splitter");
    }
    if (imported.cosObject.containsKey(COSName.b)) {
      imported.cosObject.removeItem(COSName.b);
      _logger.warning("/B entry (beads) removed by splitter");
    }
    
    // remove page links to avoid copying not needed resources 
    _processAnnotations(imported);

    _pageDictMap![page.cosObject] = imported.cosObject;
  }
  
  // Helper to import page since PDDocument might not have it yet
  PDPage _importPage(PDDocument destination, PDPage page) {
      final cloner = PDFCloneUtility(destination);
      final pageDict = cloner.cloneForNewDocument(page.cosObject) as COSDictionary;
      final newPage = PDPage(pageDict, destination.resourceCache);
      
      // We need to remove Parent so it can be added to the new tree
      pageDict.removeItem(COSName.parent);
      
      destination.addPage(newPage);
      return newPage;
  }

  void _processAnnotations(PDPage imported) {
    final annotations = imported.annotations;
    if (annotations.isEmpty) {
      return;
    }
    
    final clonedAnnotations = <PDAnnotation>[];
    for (final annotation in annotations) {
        // create a shallow clone
        final clonedDict = COSDictionary.fromDictionary(annotation.cosObject);
        final annotationClone = PDAnnotationFactory.instance.createAnnotation(clonedDict);
        
        if (annotationClone != null) {
            _annotDictMap![annotation.cosObject] = clonedDict;
            clonedAnnotations.add(annotationClone);

            if (annotationClone is PDAnnotationLink) {
                final link = annotationClone;
                PDDestination? srcDestination;
                try {
                    srcDestination = link.destination;
                } catch (_) {
                    link.destination = null;
                    link.action = null;
                }
                PDAction? action;
                if (srcDestination == null) {
                    action = link.action;
                    if (action is PDActionGoTo) {
                        try {
                            srcDestination = action.destination;
                        } catch (_) {
                            link.action = null;
                            action = null;
                        }
                    }
                }
                if (srcDestination is PDNamedDestination) {
                    srcDestination = _resolveNamedDestination(
                        srcDestination, _sourceDocument!);
                }
                if (srcDestination is PDPageDestination) {
                    final srcPageDict = _resolvePageDictionary(srcDestination.page);
                    if (srcPageDict != null) {
                        final srcArray = srcDestination.array;
                        final clonedArray = COSArray();
                        for (final entry in srcArray) {
                            clonedArray.addObject(entry);
                        }
                        final clonedDest = PDDestination.fromCOS(clonedArray);
                        if (clonedDest is PDPageDestination) {
                            _destToFixMap?[clonedDest] = srcPageDict;
                            if (action != null) {
                                final clonedActionDict =
                                    COSDictionary.fromDictionary(action.cosObject);
                                final clonedAction =
                                    PDActionFactory.instance.createFromDictionary(
                                        clonedActionDict);
                                if (clonedAction is PDActionGoTo) {
                                    clonedAction.destination = clonedDest;
                                    link.action = clonedAction;
                                } else {
                                    link.action = clonedAction;
                                }
                            } else {
                                link.destination = clonedDest;
                            }
                        }
                    }
                }
            }

            if (annotationClone is PDAnnotationWidget &&
                annotationClone.cosObject.containsKey(COSName.parent)) {
                // remove non-terminal field /Parent reference
                annotationClone.cosObject.removeItem(COSName.parent);
            }

            annotationClone.cosObject.setItem(COSName.p, imported.cosObject);
        }
    }
    imported.annotations = clonedAnnotations;
  }
  
  void _fixDestinations(PDDocument destinationDocument) {
    if (_destToFixMap == null || _pageDictMap == null) {
      return;
    }
    final pageTree = destinationDocument.documentCatalog.pages;
    for (final entry in _destToFixMap!.entries) {
      final dest = entry.key;
      final srcPageDict = entry.value;
      final mapped = _pageDictMap![srcPageDict];
      if (mapped == null) {
        dest.page = null;
        continue;
      }
      final dstPage = PDPage(mapped);
      if (pageTree.indexOf(dstPage) >= 0) {
        dest.page = mapped;
      } else {
        dest.page = null;
      }
    }
  }

  void _cloneStructureTree(PDDocument destinationDocument) {
    final srcStructureTreeRoot =
        _sourceDocument!.documentCatalog.structureTreeRoot;
    if (srcStructureTreeRoot == null) {
      return;
    }

    _structDictMap = <COSDictionary, COSDictionary>{};
    _idSet = <String>{};
    _roleSet = <COSName>{};

    final dstStructureTreeRoot = PDStructureTreeRoot();
    final dstPageTree = destinationDocument.documentCatalog.pages;

    final k1 = srcStructureTreeRoot.k;
    final k2 = _KCloner(
      dstPageTree,
      _structDictMap!,
      _pageDictMap!,
      _annotDictMap!,
      _idSet!,
      _roleSet!,
      _logger,
    ).createClone(k1, dstStructureTreeRoot.cosObject, null);
    dstStructureTreeRoot.k = k2;

    final srcParentTree = srcStructureTreeRoot.getParentTree();
    final srcNumberTreeAsMap =
        _getNumberTreeAsMap(srcParentTree);
    final dstNumberTreeAsMap = <int, PDParentTreeValue>{};

    for (var p = 0; p < dstPageTree.count; p++) {
      final page = dstPageTree[p];
      final sp1 = page.structParents;
      if (sp1 != -1) {
        _cloneTreeElement(srcNumberTreeAsMap, dstNumberTreeAsMap, sp1);
      }
      for (final ann in page.annotations) {
        final sp2 = ann.structParent;
        if (sp2 != -1) {
          _cloneTreeElement(srcNumberTreeAsMap, dstNumberTreeAsMap, sp2);
        }
        final appearance = ann.getNormalAppearanceStream();
        if (appearance != null) {
          _processResources(
              appearance.resources,
              srcNumberTreeAsMap,
              dstNumberTreeAsMap,
              <COSDictionary>{});
        }
      }
      _processResources(
          page.resources,
          srcNumberTreeAsMap,
          dstNumberTreeAsMap,
          <COSDictionary>{});
    }

    final dstNumberTreeNode = PDNumberTreeNode<PDParentTreeValue>(
        valueFactory: (base) => PDParentTreeValue(base));
    dstNumberTreeNode.setNumbers(dstNumberTreeAsMap);
    dstStructureTreeRoot.setParentTree(dstNumberTreeNode);
    final upperLimit = dstNumberTreeNode.getUpperLimit();
    if (upperLimit != null) {
      dstStructureTreeRoot.setParentTreeNextKey(upperLimit + 1);
    }

    final classMap =
        srcStructureTreeRoot.cosObject.getDictionaryObject(COSName.classMap);
    if (classMap != null) {
      dstStructureTreeRoot.cosObject[COSName.classMap] = classMap;
    }

    _cloneRoleMap(srcStructureTreeRoot, dstStructureTreeRoot);
    _cloneIDTree(srcStructureTreeRoot, dstStructureTreeRoot);

    destinationDocument.documentCatalog.structureTreeRoot =
        dstStructureTreeRoot;
  }

  void _cloneRoleMap(
      PDStructureTreeRoot srcStructTree,
      PDStructureTreeRoot destStructTree) {
    final srcDict =
        srcStructTree.cosObject.getCOSDictionary(COSName.roleMap);
    if (srcDict == null) {
      return;
    }
    final dstDict = COSDictionary();
    for (final entry in srcDict.entries) {
      if (_roleSet!.contains(entry.key)) {
        dstDict.setItem(entry.key, entry.value);
      }
    }
    destStructTree.cosObject.setItem(COSName.roleMap, dstDict);
  }

  void _cloneIDTree(
      PDStructureTreeRoot srcStructTree,
      PDStructureTreeRoot destStructTree) {
    final srcIDTree = srcStructTree.getIDTree();
    if (srcIDTree == null) {
      return;
    }
    final srcIDTreeAsMap = _getIDTreeAsMap(srcIDTree);
    final destNames = <String, PDStructureElement?>{};
    for (final entry in srcIDTreeAsMap.entries) {
      if (!_idSet!.contains(entry.key)) {
        continue;
      }
      final dstDict = _structDictMap![entry.value.cosObject];
      if (dstDict != null) {
        destNames[entry.key] = PDStructureElement(dstDict);
      }
    }
    final destIDTree = PDStructureElementNameTreeNode();
    destIDTree.setNames(destNames);
    destStructTree.setIDTree(destIDTree);
  }

  Map<int, PDParentTreeValue> _getNumberTreeAsMap(
      PDNumberTreeNode<PDParentTreeValue>? tree) {
    final result = <int, PDParentTreeValue>{};
    if (tree == null) {
      return result;
    }
    final numbers = tree.numbers;
    if (numbers != null) {
      for (final entry in numbers.entries) {
        if (entry.value != null) {
          result[entry.key] = entry.value!;
        }
      }
    }
    final kids = tree.kids;
    if (kids != null) {
      for (final kid in kids) {
        result.addAll(_getNumberTreeAsMap(kid));
      }
    }
    return result;
  }

  Map<String, PDStructureElement> _getIDTreeAsMap(
      PDStructureElementNameTreeNode tree) {
    final result = <String, PDStructureElement>{};
    final names = tree.getNames();
    if (names != null) {
      for (final entry in names.entries) {
        if (entry.value != null) {
          result[entry.key] = entry.value!;
        }
      }
    }
    final kids = tree.kids;
    if (kids != null) {
      for (final kid in kids) {
        if (kid is PDStructureElementNameTreeNode) {
          result.addAll(_getIDTreeAsMap(kid));
        }
      }
    }
    return result;
  }

  void _cloneTreeElement(
    Map<int, PDParentTreeValue> srcNumberTreeAsMap,
    Map<int, PDParentTreeValue> dstNumberTreeAsMap,
    int sp,
  ) {
    final srcObj = srcNumberTreeAsMap[sp];
    if (srcObj == null) {
      return;
    }
    final actualSrcObj = srcObj.cosObject;
    PDParentTreeValue? dstObj;
    if (actualSrcObj is COSArray) {
      final dstArray = COSArray();
      for (var i = 0; i < actualSrcObj.length; i++) {
        final srcElement = actualSrcObj.getObject(i);
        final resolved = _resolveCOSBase(srcElement);
        if (resolved is COSDictionary) {
          final mapped = _structDictMap![resolved];
          if (mapped != null) {
            dstArray.addObject(mapped);
          } else {
            dstArray.addObject(COSNull.instance);
          }
        } else {
          dstArray.addObject(COSNull.instance);
        }
      }
      dstObj = PDParentTreeValue.fromArray(dstArray);
    } else if (actualSrcObj is COSDictionary) {
      final mapped = _structDictMap![actualSrcObj];
      if (mapped != null) {
        dstObj = PDParentTreeValue.fromDictionary(mapped);
      } else {
        _logger.warning('ParentTree index $sp dictionary not found in /K');
      }
    } else {
      _logger.warning(
          'tree element neither dictionary nor array, but ${actualSrcObj.runtimeType}');
    }
    if (dstObj != null) {
      dstNumberTreeAsMap[sp] = dstObj;
    }
  }

  void _processResources(
      PDResources? res,
      Map<int, PDParentTreeValue> srcNumberTreeAsMap,
      Map<int, PDParentTreeValue> dstNumberTreeAsMap,
      Set<COSDictionary> visited) {
    if (res == null) {
      return;
    }
    if (visited.contains(res.cosObject)) {
      return;
    }
    visited.add(res.cosObject);

    for (final name in res.xObjectNames) {
      final xObject = res.getXObject(name);
      var sp2 = -1;
      if (xObject is PDFormXObject) {
        sp2 = xObject.structParents;
        _processResources(xObject.resources, srcNumberTreeAsMap,
            dstNumberTreeAsMap, visited);
      } else if (xObject is PDImageXObject) {
        sp2 = xObject.structParent;
      }
      if (sp2 != -1) {
        _cloneTreeElement(srcNumberTreeAsMap, dstNumberTreeAsMap, sp2);
      }
    }
  }

  COSDictionary? _resolvePageDictionary(COSBase? base) {
      if (base is COSObject) {
          return base.object is COSDictionary ? base.object as COSDictionary : null;
      }
      if (base is COSDictionary) {
          return base;
      }
      return null;
  }

  PDDestination? _resolveNamedDestination(PDNamedDestination dest, PDDocument doc) {
      final name = dest.name;
      // Look up in names or Dests
      // We check the source document for resolution.
      if (_sourceDocument != null) {
          final catalog = _sourceDocument!.documentCatalog;
          final names = catalog.names;
          if (names.dests != null) {
              final resolved = names.dests!.getValue(name);
              if (resolved != null) {
                  return resolved;
              }
          }
          // Also check /Dests directly in catalog if needed (PDF 1.1)
          final dests = catalog.cosObject.getCOSDictionary(COSName.dests);
          if (dests != null) {
               final dict = dests.getDictionaryObject(COSName(name));
               if (dict != null) {
                   return PDDestination.fromCOS(dict);
               }
          }
      }
      return null;
  }
}

class _KCloner {
  _KCloner(
    this._dstPageTree,
    this._structDictMap,
    this._pageDictMap,
    this._annotDictMap,
    this._idSet,
    this._roleSet,
    this._logger,
  );

  final PDPageTree _dstPageTree;
  final Map<COSDictionary, COSDictionary> _structDictMap;
  final Map<COSDictionary, COSDictionary> _pageDictMap;
  final Map<COSDictionary, COSDictionary> _annotDictMap;
  final Set<String> _idSet;
  final Set<COSName> _roleSet;
  final Logger _logger;

  COSBase? createClone(
      COSBase? src, COSBase? dstParent, COSDictionary? currentPageDict) {
    if (src == null) {
      return null;
    }
    if (src is COSObject) {
      return createClone(src.object, dstParent, currentPageDict);
    }
    if (src is COSArray) {
      return _createArrayClone(src, dstParent, currentPageDict);
    }
    if (src is COSDictionary) {
      return _createDictionaryClone(src, dstParent, currentPageDict);
    }
    return src;
  }

  COSBase? _createArrayClone(
      COSArray src, COSBase? dstParent, COSDictionary? currentPageDict) {
    final dst = COSArray();
    for (final base in src) {
      final rc = createClone(base, dstParent, currentPageDict);
      if (rc != null) {
        dst.addObject(rc);
      }
    }
    return dst.isEmpty ? null : dst;
  }

  COSBase? _createDictionaryClone(
      COSDictionary srcDict, COSBase? dstParent, COSDictionary? currentPageDict) {
    final existing = _structDictMap[srcDict];
    if (existing != null) {
      return existing;
    }
    final srcPageDict = srcDict.getCOSDictionary(COSName.pg);
    COSDictionary? dstPageDict;
    final kid = srcDict.getDictionaryObject(COSName.k);
    final type = srcDict.getCOSName(COSName.type);
    if (srcPageDict != null) {
      dstPageDict = _pageDictMap[srcPageDict];
      if (dstPageDict != null) {
        final dstPage = PDPage(dstPageDict);
        if (_dstPageTree.indexOf(dstPage) == -1) {
          return null;
        }
      } else {
        final isMcr = type == COSName.get('MCR');
        final isObjr = type == COSName.get('OBJR');
        if (isMcr || isObjr || _hasMCIDs(kid)) {
          return null;
        }
      }
    }

    if (type == COSName.get('MCR') &&
        dstPageDict == null &&
        dstParent is COSDictionary &&
        dstParent.getCOSDictionary(COSName.pg) == null) {
      return null;
    }

    final dstDict = COSDictionary();
    _structDictMap[srcDict] = dstDict;
    for (final entry in srcDict.entries) {
      final key = entry.key;
      if (key != COSName.k && key != COSName.pg && key != COSName.p) {
        dstDict.setItem(key, entry.value);
      }
    }

    if (type == COSName.get('OBJR')) {
      final srcObj = srcDict.getCOSDictionary(COSName.obj);
      final dstObj = srcObj == null ? null : _annotDictMap[srcObj];
      if (dstObj != null) {
        dstDict.setItem(COSName.obj, dstObj);
      } else if (srcObj != null) {
        _removePossibleOrphanAnnotation(
            srcObj, srcDict, currentPageDict, dstDict);
      }
      if (dstDict.entries.length == 1) {
        return null;
      }
      if (dstPageDict == null &&
          dstParent is COSDictionary &&
          dstParent.getCOSDictionary(COSName.pg) == null) {
        return null;
      }
    }

    if (type != COSName.get('OBJR') && type != COSName.get('MCR')) {
      dstDict.setItem(COSName.p, dstParent);
    }
    dstDict.setItem(COSName.pg, dstPageDict);

    final cloneKid =
        createClone(kid, dstDict, dstPageDict ?? currentPageDict);
    if (cloneKid == null && kid != null) {
      return null;
    }
    if (dstPageDict == null &&
        cloneKid == null &&
        currentPageDict == null) {
      return null;
    }
    dstDict.setItem(COSName.k, cloneKid);

    final id = dstDict.getString(COSName.id);
    if (id != null) {
      _idSet.add(id);
    }
    final s = dstDict.getCOSName(COSName.s);
    if (s != null) {
      _roleSet.add(s);
    }
    return dstDict;
  }

  bool _hasMCIDs(COSBase? kid) {
    if (kid is COSInteger) {
      return true;
    }
    if (kid is COSArray) {
      for (var i = 0; i < kid.length; i++) {
        if (kid.getObject(i) is COSInteger) {
          return true;
        }
      }
    }
    return false;
  }

  void _removePossibleOrphanAnnotation(COSDictionary srcObj,
      COSDictionary srcDict, COSDictionary? currentPageDict, COSDictionary dstDict) {
    final objType = srcObj.getDictionaryObject(COSName.type);
    final objSubtype = srcObj.getDictionaryObject(COSName.subtype);
    if (objType == COSName.get('Annot') ||
        objSubtype == COSName.get('Link')) {
      var srcPageDict = srcDict.getCOSDictionary(COSName.pg);
      srcPageDict ??= currentPageDict;
      if (srcPageDict != null) {
        final annotationArray = srcPageDict.getCOSArray(COSName.annots);
        if (annotationArray == null ||
            !_arrayContainsObject(annotationArray, srcObj)) {
          _logger.warning(
              "An annotation OBJ that isn't in the page has been removed from the structure tree");
          dstDict.removeItem(COSName.obj);
        }
      }
    }
  }

  bool _arrayContainsObject(COSArray array, COSDictionary target) {
    for (final entry in array) {
      final resolved = entry is COSObject ? entry.object : entry;
      if (identical(resolved, target)) {
        return true;
      }
    }
    return false;
  }
}

COSBase? _resolveCOSBase(COSBase? base) {
  if (base is COSObject) {
    return base.object;
  }
  return base;
}


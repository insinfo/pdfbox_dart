import 'dart:io';

import 'package:logging/logging.dart';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_number.dart';
import '../cos/cos_integer.dart';
import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_document_catalog.dart';
import '../pdmodel/pd_document_information.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/common/pd_metadata.dart';
import '../pdmodel/graphics/optionalcontent/pd_optional_content_properties.dart';
import '../pdmodel/interactive/form/pd_acro_form.dart';
import '../pdmodel/interactive/viewerpreferences/pd_viewer_preferences.dart';
import '../pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import '../pdmodel/documentinterchange/logicalstructure/pd_structure_tree_root.dart';
import '../pdmodel/common/pd_number_tree_node.dart';
import '../pdmodel/documentinterchange/logicalstructure/pd_parent_tree_value.dart';
import '../../io/random_access_write_file.dart';
import 'pdf_clone_utility.dart';

/// The mode to use when merging documents.
enum DocumentMergeMode {
  optimizeResourcesMode,
  pdfboxLegacyMode,
}

/// The mode to use when merging AcroForm between documents.
enum AcroFormMergeMode {
  joinFormFieldsMode,
  pdfboxLegacyMode,
}

/// This class will take a list of pdf documents and merge them into one document.
class PDFMergerUtility {
  static final Logger _logger = Logger('pdfbox.PDFMergerUtility');

  final List<dynamic> _sources = [];
  String? _destinationFileName;
  IOSink? _destinationStream;
  PDDocumentInformation? _destinationDocumentInformation;
  PDMetadata? _destinationMetadata;

  DocumentMergeMode _documentMergeMode = DocumentMergeMode.pdfboxLegacyMode;
  AcroFormMergeMode _acroFormMergeMode = AcroFormMergeMode.pdfboxLegacyMode;
  
  // ignore: unused_field
  int _nextFieldNum = 1;

  /// Add a source file to the list of files to merge.
  void addSource(File file) {
    _sources.add(file);
  }
  
  /// Add a source stream to the list of files to merge.
  void addSourceStream(Stream<List<int>> stream) {
    _sources.add(stream);
  }

  /// Set the name of the destination file.
  void setDestinationFileName(String destinationFileName) {
    _destinationFileName = destinationFileName;
  }

  /// Set the destination stream.
  void setDestinationStream(IOSink destinationStream) {
    _destinationStream = destinationStream;
  }
  
  void setDocumentMergeMode(DocumentMergeMode mode) {
    _documentMergeMode = mode;
  }
  
  void setAcroFormMergeMode(AcroFormMergeMode mode) {
    _acroFormMergeMode = mode;
  }

  /// Merge the list of source documents, saving the result in the destination file.
  void mergeDocuments({bool lenient = false}) {
    if (_documentMergeMode == DocumentMergeMode.pdfboxLegacyMode) {
        _legacyMergeDocuments(lenient: lenient);
    } else {
        // TODO: Implement optimized merge
        _legacyMergeDocuments(lenient: lenient);
    }
  }
  
  void _legacyMergeDocuments({bool lenient = false}) {
    final destination = PDDocument();
    try {
        for (final source in _sources) {
            PDDocument? sourceDoc;
            if (source is File) {
                sourceDoc = PDDocument.loadFromFile(source, lenient: lenient);
            } else if (source is Stream<List<int>>) {
                throw UnimplementedError('Merging from stream not fully supported yet');
            }
            
            if (sourceDoc != null) {
                try {
                    appendDocument(destination, sourceDoc);
                } finally {
                    sourceDoc.close();
                }
            }
        }
        
        if (_destinationDocumentInformation != null) {
            destination.documentInformation = _destinationDocumentInformation!;
        }
        if (_destinationMetadata != null) {
            destination.documentCatalog.metadata = _destinationMetadata;
        }
        
        if (_destinationFileName != null) {
            final output = RandomAccessWriteFile(_destinationFileName!);
            destination.save(output);
            output.close();
        } else if (_destinationStream != null) {
             throw UnimplementedError('Saving to IOSink not directly supported by PDDocument.save yet');
        } else {
            // throw StateError('No destination set');
        }
    } finally {
        destination.close();
    }
  }

  /// Appends the document to the destination document.
  void appendDocument(PDDocument destination, PDDocument source) {
    if (source.isClosed) {
        throw ArgumentError('Source document is closed');
    }
    if (destination.isClosed) {
        throw ArgumentError('Destination document is closed');
    }

    final cloner = PDFCloneUtility(destination);
    final destCatalog = destination.documentCatalog;
    final srcCatalog = source.documentCatalog;
    
    final destInfo = destination.documentInformation;
    final srcInfo = source.documentInformation;
    _mergeInto(srcInfo.cosObject, destInfo.cosObject, cloner, {});

    // use the highest version number for the resulting pdf
    final destVersion = double.tryParse(destination.version) ?? 1.4;
    final srcVersion = double.tryParse(source.version) ?? 1.4;
    if (destVersion < srcVersion) {
        destination.version = source.version;
    }

    _mergeAcroForm(cloner, destination, destCatalog, srcCatalog);

    // Merge Threads
    final threadsName = COSName('Threads');
    final destThreads = destCatalog.cosObject.getCOSArray(threadsName);
    final srcThreads = cloner.cloneForNewDocument(srcCatalog.cosObject.getCOSArray(threadsName)) as COSArray?;
    if (destThreads == null) {
        if (srcThreads != null) {
            destCatalog.cosObject[threadsName] = srcThreads;
        }
    } else {
        if (srcThreads != null) {
            for (final item in srcThreads) {
                destThreads.add(item);
            }
        }
    }

    // Merge Names
    final destNames = destCatalog.names;
    final srcNames = srcCatalog.names; 
    if (srcCatalog.cosObject.containsKey(COSName.names)) {
        cloner.cloneMerge(srcNames.cosObject, destNames.cosObject);
    }
    
    final idTreeName = COSName('IDTree');
    if (destNames.cosObject.containsKey(idTreeName)) {
        destNames.cosObject.removeItem(idTreeName);
        _logger.warning("Removed /IDTree from /Names dictionary, doesn't belong there");
    }

    // Merge Dests (Name Destination Dictionary)
    final srcDests = srcCatalog.cosObject.getCOSDictionary(COSName.dests);
    if (srcDests != null) {
        final destDests = destCatalog.cosObject.getCOSDictionary(COSName.dests);
        if (destDests == null) {
            destCatalog.cosObject[COSName.dests] = cloner.cloneForNewDocument(srcDests);
        } else {
            cloner.cloneMerge(srcDests, destDests);
        }
    }

    // Merge Outlines
    final srcOutline = srcCatalog.documentOutline;
    if (srcOutline != null) {
        final destOutline = destCatalog.documentOutline;
        if (destOutline == null || destOutline.firstChild == null) {
            final cloned = PDOutlineRoot(dictionary: cloner.cloneForNewDocument(srcOutline.cosObject) as COSDictionary);
            destCatalog.documentOutline = cloned;
        } else {
             for (final item in srcOutline.children) {
                 final clonedDict = cloner.cloneForNewDocument(item.cosObject) as COSDictionary;
                 clonedDict.removeItem(COSName.prev);
                 clonedDict.removeItem(COSName.next);
                 final clonedItem = PDOutlineItem(dictionary: clonedDict);
                 destOutline.addLast(clonedItem);
             }
        }
    }

    // Merge PageMode
    if (destCatalog.pageMode == null) {
        destCatalog.pageMode = srcCatalog.pageMode;
    }

    // Merge PageLabels
    final srcLabels = srcCatalog.cosObject.getCOSDictionary(COSName.pageLabels);
    if (srcLabels != null) {
      final destPageCount = destination.numberOfPages;
      COSArray destNums;
      var destLabels = destCatalog.cosObject.getCOSDictionary(COSName.pageLabels);
      if (destLabels == null) {
        destLabels = COSDictionary();
        destNums = COSArray();
        destLabels[COSName.nums] = destNums;
        destCatalog.cosObject[COSName.pageLabels] = destLabels;
      } else {
        destNums = destLabels.getCOSArray(COSName.nums)!;
      }
      
      final srcNums = srcLabels.getCOSArray(COSName.nums);
      if (srcNums != null) {
        final startSize = destNums.length;
        for (int i = 0; i < srcNums.length; i += 2) {
          final base = srcNums.getObject(i);
          if (base is! COSNumber) {
            _logger.severe("page labels ignored, index $i should be a number, but is $base");
            // remove what we added
            while (destNums.length > startSize) {
              destNums.removeAt(startSize);
            }
            break;
          }
          final labelIndex = base;
          final labelIndexValue = labelIndex.intValue;
          destNums.add(COSInteger(labelIndexValue + destPageCount));
          destNums.add(cloner.cloneForNewDocument(srcNums.getObject(i + 1))!);
        }
      }
    }

    // Merge Metadata
    final srcMetadata = srcCatalog.metadata;
    final destMetadata = destCatalog.metadata;
    if (destMetadata == null && srcMetadata != null) {
        final newStream = cloner.cloneForNewDocument(srcMetadata.cosStream) as COSStream;
        destCatalog.metadata = PDMetadata.fromStream(newStream);
    }

    // Merge OCProperties
    final srcOCP = srcCatalog.optionalContentProperties;
    final destOCP = destCatalog.optionalContentProperties;
    if (destOCP == null && srcOCP != null) {
        destCatalog.optionalContentProperties = PDOptionalContentProperties.fromDictionary(
            cloner.cloneForNewDocument(srcOCP.cosObject) as COSDictionary
        );
    } else if (destOCP != null && srcOCP != null) {
        cloner.cloneMerge(srcOCP.cosObject, destOCP.cosObject);
    }

    // Merge OutputIntents
    _mergeOutputIntents(srcCatalog, destCatalog, cloner);

    // Merge StructureTree
    final destStructTree = destCatalog.structureTreeRoot;
    final srcStructTree = srcCatalog.structureTreeRoot;
    if (destStructTree == null && srcStructTree != null) {
      final newTree = PDStructureTreeRoot();
      destCatalog.structureTreeRoot = newTree;
      newTree.setParentTree(PDNumberTreeNode<PDParentTreeValue>(
          valueFactory: (base) => PDParentTreeValue(base)));
      newTree.setParentTreeNextKey(0);
    }
    
    // Merge OpenAction
    final srcOpenAction = srcCatalog.cosObject.getDictionaryObject(COSName.openAction);
    final destOpenAction = destCatalog.cosObject.getDictionaryObject(COSName.openAction);
    if (destOpenAction == null && srcOpenAction != null) {
        destCatalog.cosObject[COSName.openAction] = cloner.cloneForNewDocument(srcOpenAction);
    }

    // Merge ViewerPreferences
    _mergeViewerPreferences(destCatalog, srcCatalog, cloner);

    // Merge Language
    if (destCatalog.language == null) {
        destCatalog.language = srcCatalog.language;
    }

    // Merge MarkInfo
    _mergeMarkInfo(destCatalog, srcCatalog);

    // Merge Pages
    final pageMap = <COSObject, COSObject>{};
    _mergePages(cloner, destination, destCatalog, srcCatalog, pageMap);
  }

  void _mergePages(
      PDFCloneUtility cloner,
      PDDocument destination,
      PDDocumentCatalog destCatalog,
      PDDocumentCatalog srcCatalog,
      Map<COSObject, COSObject> pageMap) {
      
      final srcPages = srcCatalog.pages;
      for (int i = 0; i < srcPages.count; i++) {
          final page = srcPages[i];
          final newPageDict = cloner.cloneForNewDocument(page.cosObject) as COSDictionary;
          newPageDict.removeItem(COSName.parent);
          
          final newPage = PDPage(newPageDict);
          newPage.cropBox = page.cropBox;
          newPage.mediaBox = page.mediaBox;
          newPage.rotation = page.rotation;
          
          final resources = page.resources;
          // Clone resources
          final newResources = PDResources(
              cloner.cloneForNewDocument(resources.cosObject) as COSDictionary
          );
          newPage.resources = newResources;
          
          destination.addPage(newPage);
      }
  }

  void _mergeAcroForm(
      PDFCloneUtility cloner,
      PDDocument destination,
      PDDocumentCatalog destCatalog,
      PDDocumentCatalog srcCatalog) {
      
      final destAcroForm = destCatalog.acroForm;
      final srcAcroForm = srcCatalog.acroForm;
      
      if (srcAcroForm == null) {
          return;
      }
      
      if (destAcroForm == null) {
          destCatalog.acroForm = PDAcroForm(
              destination.cosDocument, 
              destination.resourceCache, 
              cloner.cloneForNewDocument(srcAcroForm.cosObject) as COSDictionary
          );
      } else {
          if (_acroFormMergeMode == AcroFormMergeMode.pdfboxLegacyMode) {
              _acroFormLegacyMode(cloner, destAcroForm, srcAcroForm);
          } else {
              // Join fields mode
              _acroFormLegacyMode(cloner, destAcroForm, srcAcroForm);
          }
      }
  }

  void _acroFormLegacyMode(
      PDFCloneUtility cloner,
      PDAcroForm destAcroForm,
      PDAcroForm srcAcroForm) {
      
      final srcFields = srcAcroForm.fields;
      if (srcFields.isNotEmpty) {
          // if a form is merged multiple times using PDFBox the newly generated
          // fields starting with dummyFieldName may already exist. We need to determine the last unique 
          // number used and increment that.
          final prefix = "dummyFieldName";
          final prefixLength = prefix.length;

          for (final destField in destAcroForm.fieldTree) {
              final fieldName = destField.partialName;
              if (fieldName.startsWith(prefix)) {
                  final suffix = fieldName.substring(prefixLength);
                  if (RegExp(r'^\d+$').hasMatch(suffix)) {
                      final num = int.tryParse(suffix) ?? 0;
                      if (num >= _nextFieldNum) {
                          _nextFieldNum = num + 1;
                      }
                  }
              }
          }

          final destFieldsArray = destAcroForm.cosObject.getCOSArray(COSName.fields) ?? COSArray();
          
          for (final srcField in srcFields) {
              final dstFieldDict = cloner.cloneForNewDocument(srcField.cosObject) as COSDictionary;
              // if the form already has a field with this name then we need to rename this field
              // to prevent merge conflicts.
              if (destAcroForm.getField(srcField.fullyQualifiedName) != null) {
                  dstFieldDict.setString(COSName.t, prefix + (_nextFieldNum++).toString());
              }
              destFieldsArray.add(dstFieldDict);
          }
          destAcroForm.cosObject[COSName.fields] = destFieldsArray;
      }
  }

  void _mergeOutputIntents(PDDocumentCatalog srcCatalog, PDDocumentCatalog destCatalog, PDFCloneUtility cloner) {
      final outputIntentsName = COSName('OutputIntents');
      final srcOutputIntents = srcCatalog.cosObject.getCOSArray(outputIntentsName);
      if (srcOutputIntents == null) return;
      
      final destOutputIntents = destCatalog.cosObject.getCOSArray(outputIntentsName) ?? COSArray();
      if (!destCatalog.cosObject.containsKey(outputIntentsName)) {
          destCatalog.cosObject[outputIntentsName] = destOutputIntents;
      }
      
      for (final srcOI in srcOutputIntents) {
          if (srcOI is! COSDictionary) continue;
          destOutputIntents.add(cloner.cloneForNewDocument(srcOI)!);
      }
  }

  void _mergeViewerPreferences(PDDocumentCatalog destCatalog, PDDocumentCatalog srcCatalog, PDFCloneUtility cloner) {
      final srcVP = srcCatalog.viewerPreferences;
      if (srcVP == null) return;
      
      var destVP = destCatalog.viewerPreferences;
      if (destVP == null) {
          destVP = PDViewerPreferences(COSDictionary());
          destCatalog.viewerPreferences = destVP;
      }
      
      _mergeInto(srcVP.cosObject, destVP.cosObject, cloner, {});
  }

  void _mergeMarkInfo(PDDocumentCatalog destCatalog, PDDocumentCatalog srcCatalog) {
      final markInfoName = COSName('MarkInfo');
      final srcMark = srcCatalog.cosObject.getCOSDictionary(markInfoName);
      if (srcMark == null) return;
      
      var destMark = destCatalog.cosObject.getCOSDictionary(markInfoName);
      if (destMark == null) {
          destMark = COSDictionary();
          destCatalog.cosObject[markInfoName] = destMark;
      }
      
      destMark.setBoolean(COSName('Marked'), true);
  }

  void _mergeInto(COSDictionary src, COSDictionary dst, PDFCloneUtility cloner, Set<COSName> exclude) {
      for (final entry in src.entries) {
          if (!exclude.contains(entry.key) && !dst.containsKey(entry.key)) {
              dst[entry.key] = cloner.cloneForNewDocument(entry.value);
          }
      }
  }
}

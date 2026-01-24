import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';
import '../pdmodel/pd_document.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/common/pd_rectangle.dart';
import '../pdmodel/pd_stream.dart';
import '../pdmodel/pd_page_content_stream.dart';
import '../pdmodel/graphics/form/pd_form_xobject.dart';
import '../pdmodel/documentinterchange/markedcontent/pd_property_list.dart';
import '../pdmodel/graphics/optionalcontent/pd_optional_content_properties.dart';
import '../util/matrix.dart';
import '../../fontbox/util/bounding_box.dart';
import 'pdf_clone_utility.dart';

/// This class allows to import pages as Form XObjects into a document and use them to create layers
/// (optional content groups). It should used only on loaded documents, not on generated documents
/// because these can contain unfinished parts, e.g. font subsetting information.
class LayerUtility {
  static final Logger _logger = Logger('pdfbox.LayerUtility');

  final PDDocument _targetDoc;
  final PDFCloneUtility _cloner;

  /// Creates a new instance.
  /// [targetDoc] the PDF document to modify
  LayerUtility(this._targetDoc) : _cloner = PDFCloneUtility(_targetDoc);

  /// Returns the PDF document we work on.
  PDDocument get document => _targetDoc;

  /// Some applications may not wrap their page content in a save/restore (q/Q) pair which can
  /// lead to problems with coordinate system transformations when content is appended. This
  /// method lets you add a q/Q pair around the existing page's content.
  /// [page] the page
  void wrapInSaveRestore(PDPage page) {
    final saveGraphicsStateStream = COSStream();
    saveGraphicsStateStream.data = Uint8List.fromList('q\n'.codeUnits);

    final restoreGraphicsStateStream = COSStream();
    restoreGraphicsStateStream.data = Uint8List.fromList('Q\n'.codeUnits);

    //Wrap the existing page's content in a save/restore pair (q/Q) to have a controlled
    //environment to add additional content.
    final pageDictionary = page.cosObject;
    final contents = pageDictionary.getDictionaryObject(COSName.contents);
    
    if (contents is COSStream) {
      final array = COSArray();
      array.add(saveGraphicsStateStream);
      array.add(contents);
      array.add(restoreGraphicsStateStream);
      pageDictionary[COSName.contents] = array;
    } else if (contents is COSArray) {
      contents.insert(0, saveGraphicsStateStream);
      contents.add(restoreGraphicsStateStream);
    } else {
      throw StateError("Contents are unknown type: ${contents.runtimeType}");
    }
  }

  static final Set<String> _pageToFormFilter = {
    "Group", "LastModified", "Metadata"
  };

  /// Imports a page from some PDF file as a Form XObject so it can be placed on another page
  /// in the target document.
  /// <p>
  /// You may want to call [wrapInSaveRestore] before invoking the Form XObject to
  /// make sure that the graphics state is reset.
  /// 
  /// [sourceDoc] the source PDF document that contains the page to be copied
  /// [page] the page in the source PDF document to be copied
  /// Returns a Form XObject containing the original page's content
  PDFormXObject importPageAsForm(PDDocument sourceDoc, PDPage page) {
    _importOcProperties(sourceDoc);

    final contentStream = page.contentStreams.first;
    final bytes = contentStream.cosStream.encodedBytes() ?? Uint8List(0);
    final cosStream = COSStream();
    cosStream.data = bytes;
    cosStream[COSName.filter] = COSName.flateDecode;
    final newStream = PDStream(cosStream);
    final form = PDFormXObject(newStream);

    //Copy resources
    final pageRes = page.resources;
    final formRes = PDResources(null, null);
    _cloner.cloneMerge(pageRes, formRes);
    form.resources = formRes;

    //Transfer some values from page to form
    _transferDict(page.cosObject, form.cosObject, _pageToFormFilter);

    final matrix = form.matrix;
    final at = matrix.clone(); // AffineTransform in Java, Matrix in Dart
    final mediaBox = page.mediaBox!;
    final cropBox = page.cropBox;
    final viewBox = (cropBox != null ? cropBox : mediaBox);

    //Handle the /Rotation entry on the page dict
    final rotation = page.rotation;

    //Transform to FOP's user space
    //at.scale(1 / viewBox.getWidth(), 1 / viewBox.getHeight());
    at.translate(mediaBox.lowerLeftX - viewBox.lowerLeftX,
            mediaBox.lowerLeftY - viewBox.lowerLeftY);
    
    switch (rotation) {
      case 90:
        at.scale(viewBox.width / viewBox.height, viewBox.height / viewBox.width);
        at.translate(0, viewBox.width);
        at.rotate(3 * math.pi / 2); // 270 degrees
        break;
      case 180:
        at.translate(viewBox.width, viewBox.height);
        at.rotate(math.pi); // 180 degrees
        break;
      case 270:
        at.scale(viewBox.width / viewBox.height, viewBox.height / viewBox.width);
        at.translate(viewBox.height, 0);
        at.rotate(math.pi / 2); // 90 degrees
        break;
      default:
        //no additional transformations necessary
    }
    //Compensate for Crop Boxes not starting at 0,0
    at.translate(-viewBox.lowerLeftX, -viewBox.lowerLeftY);
    
    if (!at.isIdentity) {
        form.matrix = at;
    }

    final bbox = BoundingBox(
        lowerLeftX: viewBox.lowerLeftX,
        lowerLeftY: viewBox.lowerLeftY,
        upperRightX: viewBox.upperRightX,
        upperRightY: viewBox.upperRightY
    );
    form.boundingBox = PDRectangle(bbox.lowerLeftX, bbox.lowerLeftY, bbox.upperRightX, bbox.upperRightY);

    return form;
  }

  /// Places the given form over the existing content of the indicated page (like an overlay).
  /// The form is enveloped in a marked content section to indicate that it's part of an
  /// optional content group (OCG), here used as a layer. This optional group is returned and
  /// can be enabled and disabled through methods on [PDOptionalContentProperties].
  /// <p>
  /// You may want to call [wrapInSaveRestore] before calling this method to make
  /// sure that the graphics state is reset.
  ///
  /// [targetPage] the target page
  /// [form] the form to place
  /// [transform] the transformation matrix that controls the placement of your form. You'll
  /// need this if your page has a crop box different than the media box, or if these have negative
  /// coordinates, or if you want to scale or adjust your form.
  /// [layerName] the name for the layer/OCG to produce
  /// Returns the optional content group that was generated for the form usage
  PDOptionalContentGroup appendFormAsLayer(PDPage targetPage,
          PDFormXObject form, Matrix transform,
          String layerName) {
      final catalog = _targetDoc.documentCatalog;
      var ocprops = catalog.optionalContentProperties;
      if (ocprops == null) {
          ocprops = PDOptionalContentProperties();
          catalog.optionalContentProperties = ocprops;
      }
      if (ocprops.hasGroup(layerName)) {
          throw ArgumentError("Optional group (layer) already exists: $layerName");
      }

      final cropBox = targetPage.cropBox;
      if (cropBox != null && (cropBox.lowerLeftX < 0 || cropBox.lowerLeftY < 0)) {
          // PDFBOX-4044 
          _logger.warning("Negative cropBox $cropBox and identity transform may make your form invisible");
      }

      final layer = PDOptionalContentGroup(layerName);
      ocprops.addGroup(layer);

      final contentStream = PDPageContentStream(
              _targetDoc, targetPage, mode: PDPageContentMode.append);
      
      try {
          contentStream.beginMarkedContent(COSName.oc, propertyList: layer);
          contentStream.saveGraphicsState();
          contentStream.transform(transform.getValue(0, 0), transform.getValue(0, 1), 
                                  transform.getValue(1, 0), transform.getValue(1, 1), 
                                  transform.getValue(2, 0), transform.getValue(2, 1));
          
          contentStream.drawForm(form);

          contentStream.restoreGraphicsState();
          contentStream.endMarkedContent();
      } finally {
          contentStream.close();
      }

      return layer;
  }

  void _transferDict(COSDictionary orgDict, COSDictionary targetDict, Set<String> filter) {
      for (final entry in orgDict.entries) {
          final key = entry.key;
          if (filter.contains(key.name)) {
              targetDict[key] = _cloner.cloneForNewDocument(entry.value);
          }
      }
  }

  /// Imports OCProperties from source document to target document so hidden layers can still be
  /// hidden after import.
  ///
  /// [srcDoc] The source PDF document that contains the /OCProperties to be copied.
  void _importOcProperties(PDDocument srcDoc) {
      final srcCatalog = srcDoc.documentCatalog;
      final srcOCProperties = srcCatalog.optionalContentProperties;
      if (srcOCProperties == null) {
          return;
      }

      final dstCatalog = _targetDoc.documentCatalog;
      final dstOCProperties = dstCatalog.optionalContentProperties;

      if (dstOCProperties == null) {
          dstCatalog.optionalContentProperties = PDOptionalContentProperties.fromDictionary(
                  _cloner.cloneForNewDocument(srcOCProperties.cosObject) as COSDictionary);
      } else {
          _cloner.cloneMerge(srcOCProperties, dstOCProperties);
      }
  }
}

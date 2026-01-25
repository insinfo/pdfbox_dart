import '../../../io/exceptions.dart';
import '../../cos/cos_array.dart';
import '../../cos/cos_base.dart' show COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';
import '../common/pd_file_specification.dart';
import 'fdf_field.dart';
import 'fdf_annotation_text.dart';
import 'fdf_annotation_caret.dart';
import 'fdf_annotation_free_text.dart';
import 'fdf_annotation_file_attachment.dart';
import 'fdf_annotation_highlight.dart';
import 'fdf_annotation_ink.dart';
import 'fdf_annotation_line.dart';
import 'fdf_annotation_link.dart';
import 'fdf_annotation_circle.dart';
import 'fdf_annotation_square.dart';
import 'fdf_annotation_polygon.dart';
import 'fdf_annotation_polyline.dart';
import 'fdf_annotation_sound.dart';
import 'fdf_annotation_squiggly.dart';
import 'fdf_annotation_stamp.dart';
import 'fdf_annotation_strike_out.dart';
import 'fdf_annotation_underline.dart';
import 'package:pdfbox_dart/src/utils/xml/xml.dart';


/// FDF dictionary that is part of the FDF document.
/// Ported from org.apache.pdfbox.pdmodel.fdf.FDFDictionary
class FDFDictionary implements COSObjectable {
  FDFDictionary([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  /// Direct access to the underlying dictionary.
  COSDictionary get dictionary => _dictionary;

  /// The source file or target file: the PDF document file that this FDF file was exported from
  /// or is intended to be imported into.
  /// Returns the F entry of the FDF dictionary.
  /// Throws IOException if there is an error creating the file spec.
  PDFileSpecification? getFile() {
    try {
      return PDFileSpecification.fromCOS(_dictionary.getDictionaryObject(COSName.f));
    } catch (e) {
      throw IOException('Error creating file specification: $e');
    }
  }

  /// This will set the file specification.
  /// [fs] The file specification.
  void setFile(PDFileSpecification? fs) {
    _dictionary.setItem(COSName.f, fs);
  }

  /// This is the FDF id.
  /// Returns the FDF ID.
  COSArray? get id => _dictionary.getCOSArray(COSName.id);

  /// This will set the FDF id.
  /// [id] The new id for the FDF.
  set id(COSArray? id) {
    _dictionary.setItem(COSName.id, id);
  }

  /// This will get the status string to be displayed as the result of an action.
  /// Returns the status.
  String? get status => _dictionary.getString(COSName.status);

  /// This will set the status string.
  /// [status] The new status string.
  set status(String? status) {
    _dictionary.setString(COSName.status, status);
  }

  /// The encoding to be used for a FDF field. The default is PDFDocEncoding
  /// and this method will never return null.
  /// Returns the encoding value.
  String get encoding {
    final enc = _dictionary.getNameAsString(COSName.encoding);
    return enc ?? 'PDFDocEncoding';
  }

  /// This will set the encoding.
  /// [encoding] The new encoding.
  set encoding(String? encoding) {
    if (encoding == null) {
      _dictionary.removeItem(COSName.encoding);
    } else {
      _dictionary.setName(COSName.encoding, encoding);
    }
  }

  /// This will get the incremental updates since the PDF was last opened.
  /// Returns the differences entry of the FDF dictionary.
  COSStream? get differences => _dictionary.getCOSStream(COSName.differences);

  /// This will set the differences stream.
  /// [diff] The new differences stream.
  set differences(COSStream? diff) {
    _dictionary.setItem(COSName.differences, diff);
  }

  /// This will get the target frame in the browser to open this document.
  /// Returns the target frame.
  String? get target => _dictionary.getString(COSName.target);

  /// This will set the target frame in the browser to open this document.
  /// [target] The new target frame.
  set target(String? target) {
    _dictionary.setString(COSName.target, target);
  }

  /// This will get the list of FDF Fields.
  /// Returns a list of FDFField dictionaries or null if not set.
  /// TODO Note: FDFField class not yet ported, returns raw COSDictionary list.
  List<COSDictionary>? getFields() {
    final fieldArray = _dictionary.getCOSArray(COSName.fields);
    if (fieldArray == null) return null;
    
    final fields = <COSDictionary>[];
    for (int i = 0; i < fieldArray.length; i++) {
      final obj = fieldArray.getObject(i);
      if (obj is COSDictionary) {
        fields.add(obj);
      }
    }
    return fields;
  }

  /// This will set the list of fields.
  /// [fields] The list of field dictionaries.
  void setFields(List<COSDictionary>? fields) {
    if (fields == null) {
      _dictionary.removeItem(COSName.fields);
    } else {
      final array = COSArray();
      for (final field in fields) {
        array.add(field);
      }
      _dictionary.setItem(COSName.fields, array);
    }
  }

  /// This will get the list of FDF Pages.
  /// Returns a list of FDFPage dictionaries or null if not set.
  /// Note: FDFPage class not yet ported, returns raw COSDictionary list.
  List<COSDictionary>? getPages() {
    final pageArray = _dictionary.getCOSArray(COSName.pages);
    if (pageArray == null) return null;
    
    final pages = <COSDictionary>[];
    for (int i = 0; i < pageArray.length; i++) {
      final obj = pageArray.getObject(i);
      if (obj is COSDictionary) {
        pages.add(obj);
      }
    }
    return pages;
  }

  /// This will set the list of pages.
  /// [pages] The list of page dictionaries.
  void setPages(List<COSDictionary>? pages) {
    if (pages == null) {
      _dictionary.removeItem(COSName.pages);
    } else {
      final array = COSArray();
      for (final page in pages) {
        array.add(page);
      }
      _dictionary.setItem(COSName.pages, array);
    }
  }

  /// This will get the list of FDF Annotations.
  /// Returns a list of FDFAnnotation dictionaries or null if not set.
  /// Note: FDFAnnotation class not yet ported, returns raw COSDictionary list.
  /// Throws IOException if there is an error creating the annotation list.
  List<COSDictionary>? getAnnotations() {
    final annotArray = _dictionary.getCOSArray(COSName.annots);
    if (annotArray == null) return null;
    
    final annots = <COSDictionary>[];
    for (int i = 0; i < annotArray.length; i++) {
      final obj = annotArray.getObject(i);
      if (obj is COSDictionary) {
        annots.add(obj);
      }
    }
    return annots;
  }

  /// This will set the list of annotations.
  /// [annots] The list of annotation dictionaries.
  void setAnnotations(List<COSDictionary>? annots) {
    if (annots == null) {
      _dictionary.removeItem(COSName.annots);
    } else {
      final array = COSArray();
      for (final annot in annots) {
        array.add(annot);
      }
      _dictionary.setItem(COSName.annots, array);
    }
  }

  /// This will get the list of embedded FDF entries.
  /// Returns a list of PDFileSpecification objects or null.
  /// Throws IOException if there is an error creating the file spec.
  List<PDFileSpecification>? getEmbeddedFDFs() {
    try {
      final embeddedArray = _dictionary.getCOSArray(COSName.embeddedFdfs);
      if (embeddedArray == null) return null;
      
      final embedded = <PDFileSpecification>[];
      for (int i = 0; i < embeddedArray.length; i++) {
        final fs = PDFileSpecification.fromCOS(embeddedArray.getObject(i));
        if (fs != null) {
          embedded.add(fs);
        }
      }
      return embedded;
    } catch (e) {
      throw IOException('Error creating embedded FDF file specs: $e');
    }
  }

  /// This will set the list of embedded FDFs.
  /// [embedded] The list of embedded file specifications.
  void setEmbeddedFDFs(List<PDFileSpecification>? embedded) {
    if (embedded == null) {
      _dictionary.removeItem(COSName.embeddedFdfs);
    } else {
      final array = COSArray();
      for (final fs in embedded) {
        array.add(fs.cosObject);
      }
      _dictionary.setItem(COSName.embeddedFdfs, array);
    }
  }

  /// This will get the java script entry.
  /// Returns the java script dictionary or null if not set.
  /// Note: FDFJavaScript class not yet ported, returns raw COSDictionary.
  COSDictionary? getJavaScript() {
    return _dictionary.getCOSDictionary(COSName.javaScript);
  }

  /// This will set the JavaScript entry.
  /// [js] The javascript dictionary.
  void setJavaScript(COSDictionary? js) {
    _dictionary.setItem(COSName.javaScript, js);
  }

  /// Constructor from XML Element.
  FDFDictionary.fromXml(XmlElement fdfXML) : _dictionary = COSDictionary() {
    for (var child in fdfXML.children) {
      if (child is XmlElement) {
        switch (child.name.local) {
          case 'f':
            PDSimpleFileSpecification fs = PDSimpleFileSpecification(COSString(''));
            fs.file = child.getAttribute('href');
            setFile(fs);
            break;
          case 'ids':
            COSArray ids = COSArray();
            String? original = child.getAttribute('original');
            String? modified = child.getAttribute('modified');
            if (original != null) {
              try {
                ids.add(COSString.fromHex(original));
              } catch (e) {
                // Log warning ignored
              }
            }
            if (modified != null) {
              try {
                ids.add(COSString.fromHex(modified));
              } catch (e) {
                // Log warning ignored
              }
            }
            id = ids;
            break;
          case 'fields':
            List<COSDictionary> fieldList = [];
            for (var fieldNode in child.children) {
              if (fieldNode is XmlElement && fieldNode.name.local == 'field') {
                 try {
                   fieldList.add(FDFField.fromXml(fieldNode).cosObject);
                 } catch(e) {
                   // Log warning ignored
                 }
              }
            }
            setFields(fieldList);
            break;
          case 'annots':
            List<COSDictionary> annotList = [];
            for (var annotNode in child.children) {
              if (annotNode is XmlElement) {
                String annotationName = annotNode.name.local;
                try {
                   switch (annotationName) {
                    case "text":
                      annotList.add(FDFAnnotationText.fromXml(annotNode).cosObject);
                      break;
                    case "caret":
                      annotList.add(FDFAnnotationCaret.fromXml(annotNode).cosObject);
                      break;
                    case "freetext":
                      annotList.add(FDFAnnotationFreeText.fromXml(annotNode).cosObject);
                      break;
                    case "fileattachment":
                      annotList.add(FDFAnnotationFileAttachment.fromXml(annotNode).cosObject);
                      break;
                    case "highlight":
                      annotList.add(FDFAnnotationHighlight.fromXml(annotNode).cosObject);
                      break;
                    case "ink":
                      annotList.add(FDFAnnotationInk.fromXml(annotNode).cosObject);
                      break;
                    case "line":
                      annotList.add(FDFAnnotationLine.fromXml(annotNode).cosObject);
                      break;
                    case "link":
                      annotList.add(FDFAnnotationLink.fromXml(annotNode).cosObject);
                      break;
                    case "circle":
                      annotList.add(FDFAnnotationCircle.fromXml(annotNode).cosObject);
                      break;
                    case "square":
                      annotList.add(FDFAnnotationSquare.fromXml(annotNode).cosObject);
                      break;
                    case "polygon":
                      annotList.add(FDFAnnotationPolygon.fromXml(annotNode).cosObject);
                      break;
                    case "polyline":
                      annotList.add(FDFAnnotationPolyline.fromXml(annotNode).cosObject);
                      break;
                    case "sound":
                      annotList.add(FDFAnnotationSound.fromXml(annotNode).cosObject);
                      break;
                    case "squiggly":
                      annotList.add(FDFAnnotationSquiggly.fromXml(annotNode).cosObject);
                      break;
                    case "stamp":
                      annotList.add(FDFAnnotationStamp.fromXml(annotNode).cosObject);
                      break;
                    case "strikeout":
                      annotList.add(FDFAnnotationStrikeOut.fromXml(annotNode).cosObject);
                      break;
                    case "underline":
                      annotList.add(FDFAnnotationUnderline.fromXml(annotNode).cosObject);
                      break;
                   }
                } catch (e) {
                  // Log warning
                }
              }
            }
            setAnnotations(annotList);
            break;
        }
      }
    }
  }

  /// This will write this element as an XML document.
  /// [output] The stream to write the xml to.
  /// Throws IOException if there is an error writing the XML.
  void writeXML(StringSink output) {
    try {
      final fs = getFile();
      if (fs != null) {
        output.write('<f href="${_escapeXML(fs.file ?? '')}" />\n');
      }
      
      final ids = id;
      if (ids != null && ids.length >= 2) {
        final original = ids.getObject(0);
        final modified = ids.getObject(1);
        if (original is COSString && modified is COSString) {
          output.write('<ids original="${original.toHexString()}" ');
          output.write('modified="${modified.toHexString()}" />\n');
        }
      }
      
      final fields = getFields();
      if (fields != null && fields.isNotEmpty) {
        output.write('<fields>\n');
        for (final fieldDict in fields) {
            FDFField.fromDictionary(fieldDict).writeXML(output);
        }
        output.write('</fields>\n');
      }
    } catch (e) {
      throw IOException('Error writing FDF dictionary XML: $e');
    }
  }
  
  String _escapeXML(String input) {
    return input.replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}


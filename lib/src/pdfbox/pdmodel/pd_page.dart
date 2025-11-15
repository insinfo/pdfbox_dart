import 'dart:collection';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../../io/sequence_random_access_read.dart';
import '../contentstream/pd_content_stream.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_number.dart';
import '../cos/cos_object.dart';
import '../cos/cos_stream.dart';
import 'interactive/annotation/pd_annotation.dart';
import 'interactive/annotation/pd_annotation_factory.dart';
import 'common/pd_rectangle.dart';
import 'pd_resources.dart';
import 'pd_stream.dart';
import 'resource_cache.dart';
import '../pdfparser/pdf_stream_parser.dart';

/// High level representation of a page dictionary.
class PDPage implements PDContentStream {
  PDPage([COSDictionary? dictionary, ResourceCache? resourceCache])
      : _dictionary = dictionary ?? _createDefaultDictionary(),
        _resourceCache = resourceCache;

  static final Logger _logger = Logger('pdfbox.PDPage');
  static final Uint8List _delimiter = Uint8List.fromList(<int>[0x0a]);

  final COSDictionary _dictionary;
  ResourceCache? _resourceCache;
  List<PDAnnotation>? _annotationCache;

  COSDictionary get cosObject => _dictionary;

  /// Returns the MediaBox for this page, taking inheritance into account.
  PDRectangle? get mediaBox {
    final value = _getInheritableValue(COSName.mediaBox);
    if (value is COSArray) {
      return PDRectangle.fromCOSArray(value);
    }
    return null;
  }

  set mediaBox(PDRectangle? box) {
    if (box == null) {
      _dictionary.removeItem(COSName.mediaBox);
      return;
    }
    _dictionary[COSName.mediaBox] = box.toCOSArray();
  }

  /// Returns the CropBox rectangle, falling back to the MediaBox if absent.
  PDRectangle? get cropBox {
    final value = _getInheritableValue(COSName.cropBox);
    if (value is COSArray) {
      return PDRectangle.fromCOSArray(value);
    }
    return mediaBox;
  }

  set cropBox(PDRectangle? box) {
    if (box == null) {
      _dictionary.removeItem(COSName.cropBox);
      return;
    }
    _dictionary[COSName.cropBox] = box.toCOSArray();
  }

  /// Returns the rotation angle applied to the page.
  int get rotation {
    final value = _getInheritableValue(COSName.rotate);
    if (value is COSNumber) {
      return value.intValue;
    }
    return 0;
  }

  set rotation(int angle) {
    _dictionary.setInt(COSName.rotate, angle);
  }

  /// Returns the resources dictionary associated with the page.
  PDResources get resources {
    final value = _getInheritableValue(COSName.resources);
    if (value is COSDictionary) {
      return PDResources(value, _resourceCache);
    }
    return PDResources(null, _resourceCache);
  }

  set resources(PDResources resources) {
    _dictionary[COSName.resources] = resources.cosObject;
  }

  /// Returns the annotations associated with this page (`/Annots`).
  List<PDAnnotation> get annotations {
    final cached = _annotationCache;
    if (cached != null) {
      return cached;
    }
    final loaded = UnmodifiableListView<PDAnnotation>(_loadAnnotations());
    _annotationCache = loaded;
    return loaded;
  }

  set annotations(List<PDAnnotation> value) {
    if (value.isEmpty) {
      _dictionary.removeItem(COSName.annots);
      _annotationCache = const <PDAnnotation>[];
      return;
    }
    final array = COSArray();
    for (final annotation in value) {
      array.addObject(annotation.cosObject);
    }
    _dictionary.setItem(COSName.annots, array);
    _annotationCache = UnmodifiableListView<PDAnnotation>(List<PDAnnotation>.from(value));
  }

  void addAnnotation(PDAnnotation annotation) {
    final annots = _dictionary.getCOSArray(COSName.annots);
    if (annots == null) {
      final array = COSArray()..addObject(annotation.cosObject);
      _dictionary.setItem(COSName.annots, array);
    } else {
      annots.addObject(annotation.cosObject);
    }
    _annotationCache = null;
  }

  List<PDAnnotation> _loadAnnotations() {
    final annotsObject = _dictionary.getDictionaryObject(COSName.annots);
    if (annotsObject == null || annotsObject == COSNull.instance) {
      return const <PDAnnotation>[];
    }
    COSArray? array;
    if (annotsObject is COSArray) {
      array = annotsObject;
    } else if (annotsObject is COSObject && annotsObject.object is COSArray) {
      array = annotsObject.object as COSArray;
    }
    final factory = PDAnnotationFactory.instance;
    if (array == null) {
      final annotation = factory.createAnnotation(annotsObject);
      if (annotation == null) {
        return const <PDAnnotation>[];
      }
      return <PDAnnotation>[annotation];
    }
    final annotations = <PDAnnotation>[];
    for (final entry in array) {
      final annotation = factory.createAnnotation(entry);
      if (annotation != null) {
        annotations.add(annotation);
      }
    }
    return annotations;
  }

  /// Returns the content streams associated with the page.
  Iterable<PDStream> get contentStreams sync* {
    final contents = _dictionary.getDictionaryObject(COSName.contents);
    if (contents == null || contents == COSNull.instance) {
      return;
    }
    if (contents is COSStream) {
      yield PDStream(contents);
      return;
    }
    if (contents is COSArray) {
      for (final entry in contents) {
        final stream = _asStream(entry);
        if (stream != null) {
          yield PDStream(stream);
        }
      }
      return;
    }
    final stream = _asStream(contents);
    if (stream != null) {
      yield PDStream(stream);
    }
  }

  /// Replaces the page contents with [stream], removing any existing content.
  set contents(PDStream? stream) => setContentStream(stream);

  /// Replaces the page contents with the provided [stream].
  void setContentStream(PDStream? stream) {
    if (stream == null) {
      _dictionary.removeItem(COSName.contents);
      return;
    }
    _dictionary[COSName.contents] = stream.cosStream;
  }

  /// Replaces the page contents with [streams], preserving order.
  void setContentStreams(Iterable<PDStream> streams) {
    final list = streams.toList();
    if (list.isEmpty) {
      _dictionary.removeItem(COSName.contents);
      return;
    }
    if (list.length == 1) {
      _dictionary[COSName.contents] = list.first.cosStream;
      return;
    }
    final array = COSArray();
    for (final stream in list) {
      array.addObject(stream.cosStream);
    }
    _dictionary[COSName.contents] = array;
  }

  /// Appends [stream] to the end of the content stream list.
  void appendContentStream(PDStream stream) {
    final current = contentStreams.toList();
    current.add(stream);
    setContentStreams(current);
  }

  @override
  RandomAccessRead getContentsForStreamParsing() {
    final streams = contentStreams.toList();
    if (streams.isEmpty) {
      return RandomAccessReadBuffer();
    }

    if (streams.length == 1) {
      try {
        return streams.first.getContentsForStreamParsing();
      } on IOException catch (exception) {
        _logger.warning(
          () => 'skipped malformed content stream',
          exception,
        );
        return RandomAccessReadBuffer.fromBytes(_delimiter);
      }
    }

    final readers = <RandomAccessRead>[];
    for (final stream in streams) {
      try {
        final reader = stream.getContentsForStreamParsing();
        if (reader.length > 0) {
          readers.add(reader);
          readers.add(RandomAccessReadBuffer.fromBytes(_delimiter));
        } else {
          reader.close();
        }
      } on IOException catch (exception) {
        _logger.warning(
          () => 'malformed substream of content stream skipped',
          exception,
        );
      }
    }

    if (readers.isEmpty) {
      return RandomAccessReadBuffer();
    }
    if (readers.length == 1) {
      return readers.first;
    }
    return SequenceRandomAccessRead(readers);
  }

  /// Parses the aggregated page content streams into PDF tokens.
  List<Object?> parseContentStreamTokens() {
    final parser = PDFStreamParser(this);
    return parser.parse();
  }

  COSDictionary? get parent => _dictionary.getCOSDictionary(COSName.parent);

  set parent(COSDictionary? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.parent);
      return;
    }
    _dictionary[COSName.parent] = value;
  }

  ResourceCache? get resourceCache => _resourceCache;

  set resourceCache(ResourceCache? cache) {
    _resourceCache = cache;
  }

  static COSDictionary _createDefaultDictionary() {
    final dict = COSDictionary();
    dict.setName(COSName.type, 'Page');
    dict[COSName.mediaBox] = PDRectangle(0, 0, 612, 792).toCOSArray();
    dict[COSName.resources] = PDResources().cosObject;
    return dict;
  }

  COSBase? _getInheritableValue(COSName key) {
    COSDictionary? current = _dictionary;
    final visited = <COSDictionary>{};
    while (current != null && visited.add(current)) {
      final value = current.getDictionaryObject(key);
      if (value != null && value != COSNull.instance) {
        return value;
      }
      final parentBase = current.getDictionaryObject(COSName.parent);
      if (parentBase is COSDictionary) {
        current = parentBase;
      } else {
        current = null;
      }
    }
    return null;
  }

  COSStream? _asStream(COSBase? value) {
    if (value is COSStream) {
      return value;
    }
    if (value is COSObject) {
      final obj = value.object;
      if (obj is COSStream) {
        return obj;
      }
    }
    return null;
  }
}

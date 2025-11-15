import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../../io/random_access_write.dart';
import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_number.dart';
import '../cos/cos_object.dart';
import '../cos/cos_object_key.dart';
import '../cos/cos_stream.dart';
import '../cos/cos_string.dart';
import '../pdmodel/pd_document.dart';
import '../filter/flate_filter.dart';
import '../pdfparser/pdf_xref_stream.dart';
import '../pdfparser/xref/free_x_reference.dart';
import '../pdfparser/xref/normal_x_reference.dart';
import '../pdfparser/xref/object_stream_x_reference.dart';
import '../pdfparser/xref/x_reference_entry.dart';
import '../pdfwriter/compress/compress_parameters.dart';
import '../pdfwriter/compress/cos_writer_compression_pool.dart';
import 'cos_standard_output_stream.dart';
import 'incremental_signing_context.dart';
import 'pdf_save_options.dart';

/// Serialises a [PDDocument] into PDF bytes, supporting optional object stream
/// compression as provided by PDFBox's COSWriter.
class COSWriter {
  COSWriter(this._target, this._options)
      : _output = COSStandardOutputStream(_target);

  static final Uint8List _binaryHeader =
      Uint8List.fromList(latin1.encode('%\u00e2\u00e3\u00cf\u00d3\n'));
  static const FlateFilter _flateFilter = FlateFilter();

  final RandomAccessWrite _target;
  final PDFSaveOptions _options;
  final COSStandardOutputStream _output;

  final List<NormalXReference> _normalReferences = <NormalXReference>[];
  final List<ObjectStreamXReference> _objectStreamReferences =
      <ObjectStreamXReference>[];
  final Map<COSBase, bool> _directStateOverrides =
      LinkedHashMap<COSBase, bool>.identity();

  int _highestObjectNumber = 0;
  COSDocument? _activeCOSDocument;
  _SignatureTracking? _signatureTracking;

  void writeDocument(PDDocument document) {
    _target.clear();
    _normalReferences.clear();
    _objectStreamReferences.clear();
    _highestObjectNumber = 0;

    final cosDocument = document.cosDocument;
    final trailer = cosDocument.trailer;
    _activeCOSDocument = cosDocument;
    cosDocument.xrefTable.clear();
    _promoteInlineStreams(cosDocument);

    try {
      final Map<COSObjectKey, COSBase> documentObjects =
          <COSObjectKey, COSBase>{};
      for (final cosObject in cosDocument.objects) {
        final key = cosObject.key;
        if (key == null) {
          continue;
        }
        documentObjects[key] = cosObject.object;
        if (key.objectNumber > _highestObjectNumber) {
          _highestObjectNumber = key.objectNumber;
        }
      }

      final bool useObjectStreams =
          _options.objectStreamCompression?.isCompress ?? false;

      final Map<COSObjectKey, COSBase> indirectObjects =
          <COSObjectKey, COSBase>{};
      final Set<COSObjectKey> compressedKeys = <COSObjectKey>{};
      final List<_ObjectStreamInfo> objectStreams = <_ObjectStreamInfo>[];

      if (useObjectStreams) {
        _initialiseCompression(
          document,
          documentObjects,
          indirectObjects,
          objectStreams,
          compressedKeys,
        );
      } else {
        indirectObjects.addAll(documentObjects);
      }

      if (compressedKeys.isNotEmpty) {
        for (final key in compressedKeys) {
          indirectObjects.remove(key);
        }
      }

      _writeHeader();

      final objects = indirectObjects.entries
          .map((entry) => _IndirectObject(entry.key, entry.value))
          .toList()
        ..sort((a, b) => _compareKeys(a.key, b.key));

      for (final object in objects) {
        _writeIndirectObject(object);
      }

      final bool wroteObjectStreams = objectStreams.isNotEmpty;

      if (useObjectStreams && wroteObjectStreams) {
        cosDocument.isXRefStream = true;
        _writeCompressedXrefSection(trailer);
      } else {
        cosDocument.isXRefStream = false;
        _writeClassicXrefSection(document, trailer);
      }
      _clearUpdateStates(cosDocument);
    } finally {
      _activeCOSDocument = null;
      _restoreDirectStates();
    }
  }

  void writeIncremental(PDDocument document, RandomAccessRead original) {
    _normalReferences.clear();
    _objectStreamReferences.clear();
    _signatureTracking = null;

    final cosDocument = document.cosDocument;
    final trailer = cosDocument.trailer;
    _promoteInlineStreams(cosDocument);
    _highestObjectNumber = cosDocument.highestXRefObjectNumber;
    _activeCOSDocument = cosDocument;

    try {
      _promoteDirtyTrailerEntries(cosDocument);
      // Identify indirect objects whose contents changed since the last save.
      final updatedObjects = _collectIncrementalObjects(document);
      final trailerDirty = trailer.needsUpdateDeep();

      _target.clear();
      // Preserve the original bytes before appending the incremental section.
      final copyResult = _copyOriginal(original);
      final copiedBytes = copyResult.length;
      _output.reset(position: copiedBytes, onNewLine: copyResult.endsWithEol);

      if (updatedObjects.isEmpty && !trailerDirty) {
        _clearUpdateStates(cosDocument);
        return;
      }

      if (!copyResult.endsWithEol) {
        _output.writeEOL();
      }

      for (final object in updatedObjects) {
        _writeIndirectObject(object);
      }

      final previousStartXref =
          _options.previousStartXref ?? cosDocument.startXref;
      final startXref = _writeIncrementalXrefSection(
        document,
        trailer,
        previousStartXref,
      );
      cosDocument.startXref = startXref;
      _clearUpdateStates(cosDocument);
    } finally {
      _activeCOSDocument = null;
      _restoreDirectStates();
    }
  }

  IncrementalSigningContext prepareIncrementalSigning(
    PDDocument document,
    RandomAccessRead original,
    RandomAccessWrite target,
  ) {
    if (_target is! RandomAccessReadWriteBuffer) {
      throw StateError(
          'prepareIncrementalSigning requires a RandomAccessReadWriteBuffer target');
    }

    final RandomAccessReadWriteBuffer buffer = _target;
    buffer.clear();

    _normalReferences.clear();
    _objectStreamReferences.clear();

    final cosDocument = document.cosDocument;
    final trailer = cosDocument.trailer;
    _promoteInlineStreams(cosDocument);
    _highestObjectNumber = cosDocument.highestXRefObjectNumber;
    _activeCOSDocument = cosDocument;
    final originalLength = original.length;
    final tracking = _SignatureTracking(originalLength);
    _signatureTracking = tracking;

    try {
      _promoteDirtyTrailerEntries(cosDocument);
      final updatedObjects = _collectIncrementalObjects(document);
      final trailerDirty = trailer.needsUpdateDeep();

      if (updatedObjects.isEmpty && !trailerDirty) {
        throw StateError('No changes detected for incremental signing');
      }

      final endsWithEol = _originalEndsWithEol(original);
      _output.reset(position: originalLength, onNewLine: endsWithEol);

      if (!endsWithEol) {
        _output.writeEOL();
      }

      for (final object in updatedObjects) {
        _writeIndirectObject(object);
      }

      final previousStartXref =
          _options.previousStartXref ?? cosDocument.startXref;
      final startXref = _writeIncrementalXrefSection(
        document,
        trailer,
        previousStartXref,
      );
      cosDocument.startXref = startXref;
      _clearUpdateStates(cosDocument);
    } finally {
      _activeCOSDocument = null;
      _signatureTracking = null;
      _restoreDirectStates();
    }

    final incrementalBytes = _collectIncrementBytes(buffer);
    final signatureOffset = tracking.signatureOffset;
    final signatureLength = tracking.signatureLength;
    final byteRangeOffset = tracking.byteRangeOffset;
    final byteRangeLength = tracking.byteRangeLength;

    if (signatureOffset == 0 || signatureLength == 0) {
      throw StateError('Signature dictionary without /Contents detected');
    }
    if (byteRangeOffset == 0 ||
        byteRangeLength == 0 ||
        tracking.byteRangeArray == null) {
      throw StateError('Signature dictionary without /ByteRange placeholder');
    }

    final totalLength = originalLength + incrementalBytes.length;
    final beforeLength = signatureOffset;
    final afterOffset = signatureOffset + signatureLength;
    final afterLength = totalLength - afterOffset;
    final byteRangeValues = <int>[0, beforeLength, afterOffset, afterLength];

    _patchByteRange(incrementalBytes, tracking, byteRangeValues);

    final incSigOffset = signatureOffset - originalLength;
    final afterSigOffset = incSigOffset + signatureLength;
    final ranges = <int>[
      0,
      incSigOffset,
      afterSigOffset,
      incrementalBytes.length - afterSigOffset
    ];

    final context = IncrementalSigningContext(
      original: original,
      target: target,
      incrementalBytes: incrementalBytes,
      signatureOffsetInIncrement: incSigOffset,
      signatureLength: signatureLength,
      byteRangeArray: tracking.byteRangeArray!,
      incrementalRanges: ranges,
      totalDocumentLength: totalLength,
    )..byteRangeValues = byteRangeValues;

    buffer.clear();
    return context;
  }

  void _initialiseCompression(
    PDDocument document,
    Map<COSObjectKey, COSBase> documentObjects,
    Map<COSObjectKey, COSBase> indirectObjects,
    List<_ObjectStreamInfo> objectStreams,
    Set<COSObjectKey> compressedKeys,
  ) {
    final CompressParameters parameters =
        _options.objectStreamCompression ?? const CompressParameters();
    final compressionPool = COSWriterCompressionPool(document, parameters);

    final topLevelKeys = compressionPool.getTopLevelObjects().toSet();
    final iterator = documentObjects.entries.iterator;
    while (iterator.moveNext()) {
      final entry = iterator.current;
      if (topLevelKeys.contains(entry.key)) {
        indirectObjects[entry.key] = entry.value;
      }
    }

    for (final key in compressionPool.getObjectStreamObjects()) {
      compressedKeys.add(key);
    }

    final objectStreamWriters = compressionPool.createObjectStreams();
    var nextObjectNumber = math.max(
      _highestObjectNumber,
      compressionPool.highestXRefObjectNumber,
    );

    for (final writer in objectStreamWriters) {
      if (writer.preparedKeys.isEmpty) {
        continue;
      }
      nextObjectNumber++;
      final streamKey = COSObjectKey(nextObjectNumber, 0);
      final stream = COSStream();
      stream.key = streamKey;
      writer.writeObjectsToStream(stream);
      objectStreams
          .add(_ObjectStreamInfo(streamKey, stream, writer.preparedKeys));
      indirectObjects[streamKey] = stream;
      _highestObjectNumber = math.max(_highestObjectNumber, nextObjectNumber);

      for (var index = 0; index < writer.preparedKeys.length; index++) {
        final key = writer.preparedKeys[index];
        final base = compressionPool.getObject(key) ?? documentObjects[key];
        if (base == null) {
          continue;
        }
        _objectStreamReferences
            .add(ObjectStreamXReference(index, key, base, streamKey));
      }
    }
  }

  void _writeHeader() {
    final cosDocument = _activeCOSDocument;
    var version = cosDocument?.headerVersion ?? '1.7';
    if (_options.objectStreamCompression?.isCompress ?? false) {
      version = _ensureMinimumHeaderVersion(version, '1.5');
      if (cosDocument != null) {
        cosDocument.headerVersion = version;
      }
    }
    _writeAscii('%PDF-$version\n');
    if (_options.includeBinaryHeader) {
      _output.writeBytes(_binaryHeader);
    }
  }

  void _writeIndirectObject(_IndirectObject object) {
    final offset = _output.position;
    final key = object.key;
    final base = object.base;
    _temporarilyClearDirectFlag(base);

    _normalReferences.add(NormalXReference(offset, key, base));
    final cosDocument = _activeCOSDocument;
    if (cosDocument != null) {
      cosDocument.xrefTable[key] = offset;
      cosDocument.highestXRefObjectNumber = math.max(
        cosDocument.highestXRefObjectNumber,
        key.objectNumber,
      );
    }

    _writeAscii('${key.objectNumber} ${key.generationNumber} obj\n');
    if (base is COSStream) {
      _writeStream(base);
    } else if (base is COSDictionary) {
      _writeDictionary(base);
      _output.writeLF();
    } else {
      _writeBase(base);
      _output.writeLF();
    }
    _writeAscii('endobj\n');
  }

  void _writeStream(COSStream stream) {
    final originalLength = stream.getItem(COSName.length);
    final serialization = _prepareStreamForWrite(stream);
    final data = serialization.data;
    stream.setInt(COSName.length, data.length);

    _writeDictionary(stream);
    _output.writeLF();
    _writeAscii('stream\n');
    if (data.isNotEmpty) {
      _output.writeBytes(data);
      final last = data.isNotEmpty ? data[data.length - 1] : 0;
      if (last != 0x0a && last != 0x0d) {
        _output.writeLF();
      }
    }
    _writeAscii('endstream\n');

    if (serialization.filterAdded) {
      if (serialization.originalFilter != null) {
        stream[COSName.filter] = serialization.originalFilter!;
      } else {
        stream.removeItem(COSName.filter);
      }
    }

    if (originalLength == null) {
      stream.removeItem(COSName.length);
    } else {
      stream[COSName.length] = originalLength;
    }
  }

  void _writeDictionary(COSDictionary dictionary) {
    _detectPossibleSignature(dictionary);
    _writeAscii('<<');
    for (final entry in dictionary.entries) {
      _output.writeLF();
      _writeAscii('${entry.key} ');
      final tracking = _signatureTracking;
      if (tracking != null &&
          tracking.reachedSignature &&
          entry.key == COSName.contents) {
        tracking.signatureOffset = _output.position;
        _writeBase(entry.value);
        tracking.signatureLength = _output.position - tracking.signatureOffset;
        continue;
      }
      if (tracking != null &&
          tracking.reachedSignature &&
          entry.key == COSName.byteRange) {
        if (entry.value is COSArray) {
          tracking.byteRangeArray = entry.value as COSArray;
        }
        tracking.byteRangeOffset = _output.position + 1;
        _writeBase(entry.value);
        tracking.byteRangeLength =
            _output.position - 1 - tracking.byteRangeOffset;
        tracking.reachedSignature = false;
        continue;
      }
      _writeBase(entry.value);
    }
    _writeAscii('\n>>');
  }

  void _detectPossibleSignature(COSDictionary dictionary) {
    final tracking = _signatureTracking;
    if (tracking == null || tracking.reachedSignature) {
      return;
    }
    final typeName = _resolveName(dictionary.getDictionaryObject(COSName.type));
    final docTimeStamp = COSName.get('DocTimeStamp');
    if (typeName != COSName.sig && typeName != docTimeStamp) {
      return;
    }
    final byteRange = dictionary.getCOSArray(COSName.byteRange);
    if (byteRange == null || byteRange.length != 4) {
      return;
    }
    final third = _intFrom(byteRange.getObject(2));
    if (third != null && third > tracking.originalLength) {
      tracking.reachedSignature = true;
    }
  }

  void _writeBase(COSBase? value) {
    if (value == null || value is COSNull) {
      _writeAscii('null');
      return;
    }
    if (value is COSBoolean) {
      _writeAscii(value.value ? 'true' : 'false');
      return;
    }
    if (value is COSNumber) {
      _writeAscii(_formatNumber(value));
      return;
    }
    if (value is COSName) {
      _writeAscii(value.toString());
      return;
    }
    if (value is COSString) {
      if (value.isHex) {
        _writeAscii(_formatHexStringLiteral(value));
      } else {
        _writeAscii(_formatString(value));
      }
      return;
    }
    if (value is COSArray) {
      _writeAscii('[');
      var first = true;
      for (final element in value) {
        if (!first) {
          _writeAscii(' ');
        }
        _writeBase(element);
        first = false;
      }
      _writeAscii(']');
      return;
    }
    if (value is COSStream) {
      // Inline streams are not expected; fallback to object reference when possible.
      final key = value.key;
      if (key != null) {
        _writeAscii('${key.objectNumber} ${key.generationNumber} R');
        return;
      }
      _writeStream(value);
      return;
    }
    if (value is COSDictionary) {
      _writeDictionary(value);
      return;
    }
    if (value is COSObject) {
      final key = value.key;
      if (key != null) {
        _writeAscii('${key.objectNumber} ${key.generationNumber} R');
        return;
      }
      _writeBase(value.object);
      return;
    }
    throw StateError('Unsupported COS value ${value.runtimeType}');
  }

  void _writeClassicXrefSection(PDDocument document, COSDictionary trailer) {
    final size = _calculateClassicSize();
    final startXref = _output.position;

    _writeAscii('xref\n');
    _writeAscii('0 $size\n');
    _writeAscii('0000000000 65535 f \n');

    final offsets = List<_ClassicXrefEntry?>.filled(size, null);
    for (final entry in _normalReferences) {
      final key = entry.referencedKey;
      if (key.objectNumber >= size) {
        continue;
      }
      offsets[key.objectNumber] =
          _ClassicXrefEntry(entry.secondColumnValue, entry.thirdColumnValue);
    }

    for (var i = 1; i < size; i++) {
      final record = offsets[i];
      if (record == null) {
        _writeAscii('0000000000 00000 f \n');
      } else {
        final offsetString = record.offset.toString().padLeft(10, '0');
        final generation = record.generation.toString().padLeft(5, '0');
        _writeAscii('$offsetString $generation n \n');
      }
    }

    final rootRef = _formatReference(trailer[COSName.root]);
    final infoRef = _formatReference(trailer[COSName.info]);
    final encryptRef = _formatReference(trailer[COSName.encrypt]);
    final prevOffset = _options.previousStartXref ??
        _intFrom(trailer.getDictionaryObject(COSName.prev));
    final idArray = _resolveDocumentId(trailer);

    _writeAscii('trailer\n<<\n');
    _writeAscii('${COSName.size} $size\n');
    if (rootRef != null) {
      _writeAscii('${COSName.root} $rootRef\n');
    }
    if (infoRef != null) {
      _writeAscii('${COSName.info} $infoRef\n');
    }
    if (encryptRef != null) {
      _writeAscii('${COSName.encrypt} $encryptRef\n');
    }
    if (prevOffset != null) {
      _writeAscii('${COSName.prev} $prevOffset\n');
    }
    if (idArray != null && idArray.isNotEmpty) {
      final formatted = idArray.map(_formatIdHexString).join(' ');
      _writeAscii('${COSName.id} [$formatted]\n');
    }
    _writeAscii('>>\nstartxref\n$startXref\n%%EOF\n');
    final cosDocument = _activeCOSDocument;
    if (cosDocument != null) {
      cosDocument.startXref = startXref;
      cosDocument.highestXRefObjectNumber = math.max(
        cosDocument.highestXRefObjectNumber,
        size - 1,
      );
    }
  }

  void _writeCompressedXrefSection(COSDictionary trailer) {
    final xrefOffset = _output.position;
    final xrefKey = COSObjectKey(_highestObjectNumber + 1, 0);
    _highestObjectNumber = xrefKey.objectNumber;

    final entries = <XReferenceEntry>[FreeXReference.nullEntry]
      ..addAll(_normalReferences)
      ..addAll(_objectStreamReferences)
      ..add(NormalXReference(xrefOffset, xrefKey, COSNull.instance))
      ..sort();

    final size = _calculateCompressedSize(entries);
    final prevOffset = _options.previousStartXref ??
        _intFrom(trailer.getDictionaryObject(COSName.prev));
    final idArray = _resolveDocumentId(trailer);

    final builder = PDFXRefStream()
      ..setSize(size)
      ..addTrailerInfo(trailer);

    if (idArray != null && idArray.isNotEmpty) {
      final id = COSArray();
      for (final bytes in idArray) {
        id.addObject(COSString.fromBytes(bytes, isHex: true));
      }
      builder.stream.setItem(COSName.id, id);
    }

    for (final entry in entries) {
      builder.addEntry(entry);
    }

    final xrefStream = builder.build();
    xrefStream.key = xrefKey;

    if (prevOffset != null) {
      xrefStream.setInt(COSName.prev, prevOffset);
    }

    _writeIndirectObject(_IndirectObject(xrefKey, xrefStream));

    final startXref = xrefOffset;
    _writeAscii('startxref\n$startXref\n%%EOF\n');
    final cosDocument = _activeCOSDocument;
    if (cosDocument != null) {
      cosDocument.startXref = startXref;
      cosDocument.highestXRefObjectNumber = math.max(
        cosDocument.highestXRefObjectNumber,
        _highestObjectNumber,
      );
    }
  }

  _CopyResult _copyOriginal(RandomAccessRead original) {
    final initialPosition = original.position;
    original.seek(0);
    final length = original.length;
    var remaining = length;
    final bufferSize = 8192;
    final buffer = Uint8List(bufferSize);
    int? lastByte;
    while (remaining > 0) {
      final toRead = math.min(bufferSize, remaining);
      final read = original.readBuffer(buffer, 0, toRead);
      if (read <= 0) {
        break;
      }
      _target.writeBytes(buffer, 0, read);
      remaining -= read;
      lastByte = buffer[read - 1];
    }
    original.seek(initialPosition);
    return _CopyResult(length - remaining, lastByte);
  }

  List<_IndirectObject> _collectIncrementalObjects(PDDocument document) {
    final cosDocument = document.cosDocument;
    final result = <_IndirectObject>[];
    for (final cosObject in cosDocument.objects) {
      final key = cosObject.key;
      if (key == null) {
        continue;
      }
      // Include objects that are either new (no xref entry yet) or flagged dirty.
      final hasRef = cosDocument.xrefTable.containsKey(key);
      final isDirty = cosObject.needsUpdateDeep();
      if (!hasRef || isDirty) {
        result.add(_IndirectObject(key, cosObject.object));
      }
      _highestObjectNumber = math.max(_highestObjectNumber, key.objectNumber);
    }
    result.sort((a, b) => _compareKeys(a.key, b.key));
    return result;
  }

  int _writeIncrementalXrefSection(
    PDDocument document,
    COSDictionary trailer,
    int? previousStartXref,
  ) {
    final cosDocument = document.cosDocument;
    if (!cosDocument.isXRefStream) {
      cosDocument.hasHybridXRef = false;
      cosDocument.isXRefStream = false;
      return _writeIncrementalXrefTable(
        document,
        trailer,
        previousStartXref,
      );
    }
    if (cosDocument.hasHybridXRef) {
      return _writeIncrementalHybridXref(
        document,
        trailer,
        previousStartXref,
      );
    }
    return _writeIncrementalXrefStream(
      document,
      trailer,
      previousStartXref,
    );
  }

  int _writeIncrementalXrefTable(
    PDDocument document,
    COSDictionary trailer,
    int? previousStartXref, {
    int? hybridXrefStreamOffset,
    NormalXReference? hybridXrefEntry,
  }) {
    final cosDocument = document.cosDocument;
    final startXref = _output.position;

    _writeAscii('xref\n');
    _writeAscii('0 1\n');
    _writeAscii('0000000000 65535 f \n');

    final entries = List<NormalXReference>.from(_normalReferences);
    if (hybridXrefEntry != null) {
      entries.add(hybridXrefEntry);
    }
    entries.sort((a, b) => _compareKeys(a.referencedKey, b.referencedKey));

    if (entries.isNotEmpty) {
      var currentStart = entries.first.referencedKey.objectNumber;
      final buffer = <NormalXReference>[];

      void flushBuffer() {
        if (buffer.isEmpty) {
          return;
        }
        _writeAscii('$currentStart ${buffer.length}\n');
        for (final entry in buffer) {
          final offsetString =
              entry.secondColumnValue.toString().padLeft(10, '0');
          final generation = entry.thirdColumnValue.toString().padLeft(5, '0');
          _writeAscii('$offsetString $generation n \n');
        }
        buffer.clear();
      }

      for (final entry in entries) {
        if (buffer.isEmpty) {
          currentStart = entry.referencedKey.objectNumber;
          buffer.add(entry);
          continue;
        }
        final expected = currentStart + buffer.length;
        final current = entry.referencedKey.objectNumber;
        if (current == expected) {
          buffer.add(entry);
        } else {
          flushBuffer();
          currentStart = current;
          buffer.add(entry);
        }
      }
      flushBuffer();
    }

    final size = math.max(
          cosDocument.highestXRefObjectNumber,
          _highestObjectNumber,
        ) +
        1;
    trailer.setInt(COSName.size, size);
    if (previousStartXref != null) {
      trailer.setInt(COSName.prev, previousStartXref);
    } else {
      trailer.removeItem(COSName.prev);
    }
    if (hybridXrefStreamOffset != null) {
      trailer.setInt(COSName.xrefStm, hybridXrefStreamOffset);
    } else {
      trailer.removeItem(COSName.xrefStm);
    }

    final rootRef = _formatReference(trailer[COSName.root]);
    final infoRef = _formatReference(trailer[COSName.info]);
    final encryptRef = _formatReference(trailer[COSName.encrypt]);
    final idArray = _resolveDocumentId(trailer);

    _writeAscii('trailer\n<<\n');
    _writeAscii('${COSName.size} $size\n');
    if (rootRef != null) {
      _writeAscii('${COSName.root} $rootRef\n');
    }
    if (infoRef != null) {
      _writeAscii('${COSName.info} $infoRef\n');
    }
    if (encryptRef != null) {
      _writeAscii('${COSName.encrypt} $encryptRef\n');
    }
    if (previousStartXref != null) {
      _writeAscii('${COSName.prev} $previousStartXref\n');
    }
    if (hybridXrefStreamOffset != null) {
      _writeAscii('${COSName.xrefStm} $hybridXrefStreamOffset\n');
    }
    if (idArray != null && idArray.isNotEmpty) {
      final formatted = idArray.map(_formatIdHexString).join(' ');
      _writeAscii('${COSName.id} [$formatted]\n');
    }
    _writeAscii('>>\nstartxref\n$startXref\n%%EOF\n');
    cosDocument.highestXRefObjectNumber = size - 1;
    return startXref;
  }

  int _writeIncrementalXrefStream(
    PDDocument document,
    COSDictionary trailer,
    int? previousStartXref,
  ) {
    final info = _writeIncrementalXrefStreamObject(
      document,
      trailer,
      previousStartXref,
    );
    trailer.removeItem(COSName.xrefStm);
    final startXref = info.offset;
    _writeAscii('startxref\n$startXref\n%%EOF\n');
    return startXref;
  }

  int _writeIncrementalHybridXref(
    PDDocument document,
    COSDictionary trailer,
    int? previousStartXref,
  ) {
    final info = _writeIncrementalXrefStreamObject(
      document,
      trailer,
      previousStartXref,
    );
    return _writeIncrementalXrefTable(
      document,
      trailer,
      previousStartXref,
      hybridXrefStreamOffset: info.offset,
      hybridXrefEntry: info.selfEntry,
    );
  }

  _XrefStreamInfo _writeIncrementalXrefStreamObject(
    PDDocument document,
    COSDictionary trailer,
    int? previousStartXref,
  ) {
    final cosDocument = document.cosDocument;
    final xrefOffset = _output.position;
    final xrefKey = COSObjectKey(_highestObjectNumber + 1, 0);
    _highestObjectNumber = xrefKey.objectNumber;

    final selfEntry = NormalXReference(xrefOffset, xrefKey, COSNull.instance);

    final entries = <XReferenceEntry>[FreeXReference.nullEntry]
      ..addAll(_normalReferences)
      ..addAll(_objectStreamReferences)
      ..add(selfEntry)
      ..sort();

    final size = _calculateCompressedSize(entries);
    trailer.setInt(COSName.size, size);
    if (previousStartXref != null) {
      trailer.setInt(COSName.prev, previousStartXref);
    } else {
      trailer.removeItem(COSName.prev);
    }

    final builder = PDFXRefStream()
      ..setSize(size)
      ..addTrailerInfo(trailer);

    final idArray = _resolveDocumentId(trailer);
    if (idArray != null && idArray.isNotEmpty) {
      final id = COSArray();
      for (final bytes in idArray) {
        id.addObject(COSString.fromBytes(bytes, isHex: true));
      }
      builder.stream.setItem(COSName.id, id);
    }

    for (final entry in entries) {
      builder.addEntry(entry);
    }

    final xrefStream = builder.build();
    xrefStream.key = xrefKey;

    if (previousStartXref != null) {
      xrefStream.setInt(COSName.prev, previousStartXref);
    } else {
      xrefStream.removeItem(COSName.prev);
    }

    _writeIndirectObject(_IndirectObject(xrefKey, xrefStream));

    cosDocument.highestXRefObjectNumber = math.max(
      cosDocument.highestXRefObjectNumber,
      _highestObjectNumber,
    );
    cosDocument.isXRefStream = true;

    return _XrefStreamInfo(
      offset: xrefOffset,
      key: xrefKey,
      selfEntry: selfEntry,
    );
  }

  int _calculateClassicSize() {
    var max = 0;
    for (final entry in _normalReferences) {
      final key = entry.referencedKey;
      max = math.max(max, key.objectNumber);
    }
    return max + 1;
  }

  int _calculateCompressedSize(List<XReferenceEntry> entries) {
    var max = 0;
    for (final entry in entries) {
      final key = entry.referencedKey;
      if (key == null) {
        continue;
      }
      max = math.max(max, key.objectNumber);
    }
    return max + 1;
  }

  String? _formatReference(COSBase? base) {
    if (base is COSObject) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    }
    if (base is COSDictionary) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    } else if (base is COSStream) {
      final key = base.key;
      if (key != null) {
        return '${key.objectNumber} ${key.generationNumber} R';
      }
    }
    return null;
  }

  COSName? _resolveName(COSBase? base) {
    if (base is COSName) {
      return base;
    }
    if (base is COSObject) {
      return _resolveName(base.object);
    }
    return null;
  }

  int? _intFrom(COSBase? base) {
    if (base is COSNumber) {
      return base.intValue;
    }
    if (base is COSObject) {
      return _intFrom(base.object);
    }
    return null;
  }

  List<Uint8List>? _resolveDocumentId(COSDictionary trailer) {
    final override = _options.overrideDocumentId;
    if (override != null && override.isNotEmpty) {
      if (override.length == 1) {
        final value = Uint8List.fromList(override.first);
        return <Uint8List>[value, Uint8List.fromList(value)];
      }
      return override
          .map((bytes) => Uint8List.fromList(bytes))
          .toList(growable: false);
    }

    final existing = trailer.getDictionaryObject(COSName.id);
    if (existing is COSArray && existing.isNotEmpty) {
      final ids = <Uint8List>[];
      for (final entry in existing) {
        if (entry is COSString) {
          ids.add(Uint8List.fromList(entry.bytes));
        }
      }
      if (ids.isNotEmpty) {
        if (ids.length == 1) {
          ids.add(Uint8List.fromList(ids.first));
        }
        return ids;
      }
    }

    if (!_options.generateDocumentId) {
      return null;
    }

    final seed = _options.documentIdSeed ?? _defaultIdSeed();
    final digest = md5.convert(seed).bytes;
    final idBytes = Uint8List.fromList(digest);
    return <Uint8List>[idBytes, Uint8List.fromList(idBytes)];
  }

  Uint8List _defaultIdSeed() {
    final buffer = BytesBuilder(copy: false);
    final now = DateTime.now().toUtc();
    buffer.add(utf8.encode(now.toIso8601String()));
    buffer.addByte(_normalReferences.length & 0xff);
    buffer.addByte(_objectStreamReferences.length & 0xff);
    final random = math.Random();
    final randomData = ByteData(4)..setUint32(0, random.nextInt(0xffffffff));
    buffer.add(randomData.buffer.asUint8List());
    return buffer.toBytes();
  }

  String _formatIdHexString(Uint8List bytes) {
    final buffer = StringBuffer('<');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }

  String _formatNumber(COSNumber number) {
    if (number is COSInteger) {
      return number.intValue.toString();
    }
    final double value = number.doubleValue;
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _formatString(COSString string) {
    final buffer = StringBuffer('(');
    final bytes = string.bytes;
    for (final byte in bytes) {
      switch (byte) {
        case 0x08:
          buffer.write('\\b');
          break;
        case 0x09:
          buffer.write('\\t');
          break;
        case 0x0a:
          buffer.write('\\n');
          break;
        case 0x0c:
          buffer.write('\\f');
          break;
        case 0x0d:
          buffer.write('\\r');
          break;
        case 0x28:
          buffer.write('\\(');
          break;
        case 0x29:
          buffer.write('\\)');
          break;
        case 0x5c:
          buffer.write('\\\\');
          break;
        default:
          if (byte < 0x20 || byte > 0x7e) {
            buffer
              ..write('\\')
              ..write(byte.toRadixString(8).padLeft(3, '0'));
          } else {
            buffer.writeCharCode(byte);
          }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _formatHexStringLiteral(COSString string) {
    final bytes = string.bytes;
    final buffer = StringBuffer('<');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    buffer.write('>');
    return buffer.toString().toUpperCase();
  }

  void _writeAscii(String value) {
    if (value.isEmpty) {
      return;
    }
    _output.writeBytes(Uint8List.fromList(latin1.encode(value)));
  }

  String _ensureMinimumHeaderVersion(String current, String minimum) {
    final currentParts = _parseVersionParts(current);
    final minimumParts = _parseVersionParts(minimum);
    final comparison = _compareVersionParts(currentParts, minimumParts);
    if (comparison >= 0) {
      return current.trim();
    }
    return '${minimumParts[0]}.${minimumParts[1]}';
  }

  List<int> _parseVersionParts(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <int>[1, 4];
    }
    final segments = trimmed.split('.');
    final major = int.tryParse(segments.first) ?? 1;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    return <int>[major, minor];
  }

  int _compareVersionParts(List<int> a, List<int> b) {
    final majorComparison = a[0].compareTo(b[0]);
    if (majorComparison != 0) {
      return majorComparison;
    }
    return a[1].compareTo(b[1]);
  }

  int _compareKeys(COSObjectKey a, COSObjectKey b) {
    final objectComparison = a.objectNumber.compareTo(b.objectNumber);
    if (objectComparison != 0) {
      return objectComparison;
    }
    return a.generationNumber.compareTo(b.generationNumber);
  }

  void _clearUpdateStates(COSDocument cosDocument) {
    cosDocument.markAllClean();
  }

  void _restoreDirectStates() {
    if (_directStateOverrides.isEmpty) {
      return;
    }
    _directStateOverrides.forEach((base, original) {
      base.isDirect = original;
    });
    _directStateOverrides.clear();
  }

  void _promoteInlineStreams(COSDocument cosDocument) {
    final visited = LinkedHashSet<COSBase>.identity();
    for (final cosObject in List<COSObject>.from(cosDocument.objects)) {
      _promoteInlineStreamsRecursive(
        cosObject.object,
        cosDocument,
        visited,
      );
    }
    _promoteInlineStreamsRecursive(cosDocument.trailer, cosDocument, visited);
  }

  void _promoteInlineStreamsRecursive(
    COSBase? base,
    COSDocument cosDocument,
    Set<COSBase> visited, {
    COSDictionary? parentDictionary,
    COSName? dictionaryKey,
    COSArray? parentArray,
    int? arrayIndex,
  }) {
    if (base == null) {
      return;
    }
    if (base is COSObject) {
      _promoteInlineStreamsRecursive(
        base.object,
        cosDocument,
        visited,
        parentDictionary: parentDictionary,
        dictionaryKey: dictionaryKey,
        parentArray: parentArray,
        arrayIndex: arrayIndex,
      );
      return;
    }
    if (!visited.add(base)) {
      return;
    }

    if (base is COSStream && base.key == null) {
      final promoted = cosDocument.createObject(base);
      if (parentDictionary != null && dictionaryKey != null) {
        parentDictionary[dictionaryKey] = promoted;
      } else if (parentArray != null && arrayIndex != null) {
        parentArray[arrayIndex] = promoted;
      }
    }

    if (base is COSDictionary) {
      final entries = List<MapEntry<COSName, COSBase>>.from(base.entries);
      for (final entry in entries) {
        _promoteInlineStreamsRecursive(
          entry.value,
          cosDocument,
          visited,
          parentDictionary: base,
          dictionaryKey: entry.key,
        );
      }
      return;
    }

    if (base is COSArray) {
      for (var index = 0; index < base.length; index++) {
        _promoteInlineStreamsRecursive(
          base[index],
          cosDocument,
          visited,
          parentArray: base,
          arrayIndex: index,
        );
      }
    }
  }

  void _temporarilyClearDirectFlag(COSBase? base) {
    if (base == null) {
      return;
    }
    if (base is COSObject) {
      _temporarilyClearDirectFlag(base.object);
      return;
    }
    if (base is! COSDictionary && base is! COSStream && base is! COSArray) {
      return;
    }
    if (!base.isDirect) {
      return;
    }
    _directStateOverrides.putIfAbsent(base, () => true);
    base.isDirect = false;
  }

  void _promoteDirtyTrailerEntries(COSDocument cosDocument) {
    final trailer = cosDocument.trailer;
    final infoEntry = trailer[COSName.info];
    // Ensure modified trailer dictionaries (e.g., /Info) gain object ids so the
    // incremental section can serialize their updates without rewriting the body.
    if (infoEntry is COSDictionary && infoEntry.needsUpdateDeep()) {
      _temporarilyClearDirectFlag(infoEntry);
      final promoted = cosDocument.createObject(infoEntry);
      trailer[COSName.info] = promoted;
    }
  }

  bool _originalEndsWithEol(RandomAccessRead source) {
    if (source.length == 0) {
      return true;
    }
    final current = source.position;
    try {
      final lastIndex = source.length - 1;
      source.seek(lastIndex);
      final last = source.read();
      if (last == -1) {
        return true;
      }
      if (last == 0x0a) {
        return true;
      }
      if (last == 0x0d) {
        if (lastIndex == 0) {
          return true;
        }
        source.seek(lastIndex - 1);
        final prev = source.read();
        return prev == 0x0a;
      }
      return false;
    } finally {
      source.seek(current);
    }
  }

  Uint8List _collectIncrementBytes(RandomAccessReadWriteBuffer buffer) {
    final length = buffer.length;
    if (length == 0) {
      return Uint8List(0);
    }
    final data = Uint8List(length);
    buffer.seek(0);
    buffer.readFully(data);
    return data;
  }

  void _patchByteRange(
    Uint8List bytes,
    _SignatureTracking tracking,
    List<int> values,
  ) {
    final start = tracking.byteRangeOffset - tracking.originalLength;
    if (start < 0 || start + tracking.byteRangeLength > bytes.length) {
      throw StateError('Calculated ByteRange offset outside incremental bytes');
    }
    final rangeString = '0 ${values[1]} ${values[2]} ${values[3]}]';
    final encoded = latin1.encode(rangeString);
    for (var i = 0; i < tracking.byteRangeLength; i++) {
      bytes[start + i] = i < encoded.length ? encoded[i] : 0x20;
    }
    final array = tracking.byteRangeArray!;
    if (array.length >= 4) {
      array[0] = COSInteger(0);
      array[1] = COSInteger(values[1]);
      array[2] = COSInteger(values[2]);
      array[3] = COSInteger(values[3]);
      array.isDirect = true;
    }
  }

  _StreamSerialization _prepareStreamForWrite(COSStream stream) {
    final originalFilter = stream.getItem(COSName.filter);
    final data = stream.encodedBytes(copy: false) ?? Uint8List(0);

    if (!_options.compressStreams || originalFilter != null || data.isEmpty) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    final compressed = _flateFilter.encode(data, COSDictionary(), 0);
    if (_options.compressOnlyIfSmaller && compressed.length >= data.length) {
      return _StreamSerialization(data, originalFilter: originalFilter);
    }

    stream[COSName.filter] = COSName.flateDecode;
    return _StreamSerialization(
      compressed,
      originalFilter: originalFilter,
      filterAdded: true,
    );
  }
}

class _IndirectObject {
  _IndirectObject(this.key, this.base);

  final COSObjectKey key;
  final COSBase base;
}

class _ObjectStreamInfo {
  _ObjectStreamInfo(this.key, this.stream, this.objectKeys);

  final COSObjectKey key;
  final COSStream stream;
  final List<COSObjectKey> objectKeys;
}

class _ClassicXrefEntry {
  _ClassicXrefEntry(this.offset, this.generation);

  final int offset;
  final int generation;
}

class _SignatureTracking {
  _SignatureTracking(this.originalLength);

  final int originalLength;
  bool reachedSignature = false;
  int signatureOffset = 0;
  int signatureLength = 0;
  int byteRangeOffset = 0;
  int byteRangeLength = 0;
  COSArray? byteRangeArray;
}

class _StreamSerialization {
  const _StreamSerialization(
    this.data, {
    this.originalFilter,
    this.filterAdded = false,
  });

  final Uint8List data;
  final COSBase? originalFilter;
  final bool filterAdded;
}

class _XrefStreamInfo {
  const _XrefStreamInfo({
    required this.offset,
    required this.key,
    required this.selfEntry,
  });

  final int offset;
  final COSObjectKey key;
  final NormalXReference selfEntry;
}

class _CopyResult {
  const _CopyResult(this.length, this.lastByte);

  final int length;
  final int? lastByte;

  bool get endsWithEol => lastByte == 0x0a || lastByte == 0x0d;
}

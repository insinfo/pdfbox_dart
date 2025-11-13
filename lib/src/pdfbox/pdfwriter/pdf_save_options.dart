/// Configuration options for the low-level PDF serializer.
import 'dart:typed_data';

import 'compress/compress_parameters.dart';

/// Configuration options for the low-level PDF serializer.
class PDFSaveOptions {
  const PDFSaveOptions({
    this.includeBinaryHeader = true,
    this.compressStreams = false,
    this.compressOnlyIfSmaller = true,
    this.overrideDocumentId,
    this.generateDocumentId = false,
    this.documentIdSeed,
    this.previousStartXref,
    this.objectStreamCompression,
  });

  /// When true an additional binary comment is written after the header,
  /// matching the behaviour recommended by the PDF specification.
  final bool includeBinaryHeader;

  /// When true streams without filters are compressed using Flate.
  final bool compressStreams;

  /// Only applies when [compressStreams] is true. When enabled the writer will
  /// keep the original bytes if compression does not reduce the size.
  final bool compressOnlyIfSmaller;

  /// Overrides the document ID array in the trailer. Provide one or two entries
  /// (when a single entry is supplied it will be duplicated, mirroring the
  /// behaviour of PDFBox's ID creation).
  final List<Uint8List>? overrideDocumentId;

  /// Generates a document ID when the trailer does not already contain one and
  /// [overrideDocumentId] is not supplied.
  final bool generateDocumentId;

  /// Seed used when [generateDocumentId] is true. If omitted, a seed derived
  /// from the current time and document statistics is used.
  final Uint8List? documentIdSeed;

  /// Explicitly sets the `/Prev` value in the trailer when provided. Useful for
  /// incremental update workflows.
  final int? previousStartXref;

  /// Enables object stream compression when provided. When null object streams
  /// are not used and the writer emits a classic cross-reference table.
  final CompressParameters? objectStreamCompression;
}

import 'dart:math' as math;
import 'dart:typed_data';

import '../../decoder/decoder_specs.dart';
import '../../image/coord.dart';
import '../header_info.dart';

class _TilePartInfo {
  int? length;
  Uint8List? packedHeaders;
  final Map<int, Uint8List> pptSegments = <int, Uint8List>{};
}

/// Partial port of JJ2000's `HeaderDecoder`.
///
/// The real implementation parses JPEG 2000 main and tile-part headers to
/// populate [HeaderInfo] and [DecoderSpecs]. For now we model the data the
/// rest of the pipeline expects while leaving TODO markers where parsing
/// logic must be restored.
class HeaderDecoder {
  HeaderDecoder({
    required this.decSpec,
    required this.headerInfo,
    required this.numComps,
    required this.imgWidth,
    required this.imgHeight,
    required this.imgULX,
    required this.imgULY,
    required this.nomTileWidth,
    required this.nomTileHeight,
    required this.cbULX,
    required this.cbULY,
    required List<int> compSubsX,
    required List<int> compSubsY,
    required this.maxCompImgWidth,
    required this.maxCompImgHeight,
    required Coord tilingOrigin,
    this.precinctPartitionFlag = false,
  })  : compSubsX = List<int>.unmodifiable(compSubsX),
        compSubsY = List<int>.unmodifiable(compSubsY),
        tilingOrigin = Coord.copy(tilingOrigin);

  /// Convenience constructor for tests or provisional call sites.
  ///
  /// All geometry fields default to zero while preserving the provided
  /// component count and sub-sampling factors. Real parsing code should avoid
  /// this path.
  HeaderDecoder.placeholder({
    required this.decSpec,
    required this.headerInfo,
    required this.numComps,
    List<int>? compSubsX,
    List<int>? compSubsY,
  })  : imgWidth = 0,
        imgHeight = 0,
        imgULX = 0,
        imgULY = 0,
        nomTileWidth = 0,
        nomTileHeight = 0,
        cbULX = 0,
        cbULY = 0,
        maxCompImgWidth = 0,
        maxCompImgHeight = 0,
        tilingOrigin = Coord(0, 0),
        precinctPartitionFlag = false,
        compSubsX = List<int>.unmodifiable(compSubsX ?? List<int>.filled(numComps, 1)),
        compSubsY = List<int>.unmodifiable(compSubsY ?? List<int>.filled(numComps, 1));

  final HeaderInfo headerInfo;
  final int numComps;
  final int imgWidth;
  final int imgHeight;
  final int imgULX;
  final int imgULY;
  final int nomTileWidth;
  final int nomTileHeight;
  final int cbULX;
  final int cbULY;
  final List<int> compSubsX;
  final List<int> compSubsY;
  final int maxCompImgWidth;
  final int maxCompImgHeight;
  final Coord tilingOrigin;
  final bool precinctPartitionFlag;
  final DecoderSpecs decSpec;

  /// Number of tile-parts per tile. Populated by the codestream reader.
  List<int> nTileParts = <int>[];

  final Map<int, Map<int, _TilePartInfo>> _tilePartInfo = <int, Map<int, _TilePartInfo>>{};
  final Map<int, Uint8List> _packedHeaders = <int, Uint8List>{};
  final List<Uint8List?> _ppmMarkerData = <Uint8List?>[];
  final List<int> _tilePartTiles = <int>[];
  bool _packedHeadersDirty = false;
  bool _ppmSeen = false;

  int getNumComps() => numComps;
  int getImgWidth() => imgWidth;
  int getImgHeight() => imgHeight;
  int getImgULX() => imgULX;
  int getImgULY() => imgULY;
  int getNomTileWidth() => nomTileWidth;
  int getNomTileHeight() => nomTileHeight;
  int getCbULX() => cbULX;
  int getCbULY() => cbULY;

  int getCompSubsX(int comp) => comp < compSubsX.length ? compSubsX[comp] : 1;
  int getCompSubsY(int comp) => comp < compSubsY.length ? compSubsY[comp] : 1;

  int getMaxCompImgWidth() => maxCompImgWidth;
  int getMaxCompImgHeight() => maxCompImgHeight;

  Coord getTilingOrigin(Coord? reuse) {
    if (reuse != null) {
      reuse
        ..x = tilingOrigin.x
        ..y = tilingOrigin.y;
      return reuse;
    }
    return Coord(tilingOrigin.x, tilingOrigin.y);
  }

  bool precinctPartitionUsed() => precinctPartitionFlag;

  // TODO(jj2000): Port the full header parsing logic, populating DecoderSpecs
  // and HeaderInfo from a RandomAccessIO source.

  void parsePocMarker(
    Uint8List markerPayload, {
    required bool isMainHeader,
    required int tileIdx,
    int tilePartIdx = 0,
  }) {
    if (markerPayload.length < 2) {
      throw ArgumentError('POC marker payload too short');
    }

    final view = ByteData.view(
      markerPayload.buffer,
      markerPayload.offsetInBytes,
      markerPayload.lengthInBytes,
    );

    var offset = 0;
    final lpoc = view.getUint16(offset);
    offset += 2;

    if (lpoc > markerPayload.length) {
      throw ArgumentError('POC marker length $lpoc exceeds payload size ${markerPayload.length}');
    }

    final useShort = numComps >= 256;
    final changeStride = 5 + (useShort ? 4 : 2);
    if (changeStride <= 0 || lpoc < 2 || (lpoc - 2) % changeStride != 0) {
      throw ArgumentError('Invalid POC marker length $lpoc for component count $numComps');
    }

    final newChanges = (lpoc - 2) ~/ changeStride;
    if (newChanges <= 0) {
      return;
    }

    final key = isMainHeader ? 'main' : 't$tileIdx';
    final existing = headerInfo.poc[key];
    var existingChanges = 0;
    List<int> prevRspoc = const <int>[];
    List<int> prevCspoc = const <int>[];
    List<int> prevLyepoc = const <int>[];
    List<int> prevRepoc = const <int>[];
    List<int> prevCepoc = const <int>[];
    List<int> prevPpoc = const <int>[];

    late final HeaderInfoPOC poc;
    if (existing != null && existing.rspoc.isNotEmpty) {
      existingChanges = existing.rspoc.length;
      prevRspoc = List<int>.from(existing.rspoc);
      prevCspoc = List<int>.from(existing.cspoc);
      prevLyepoc = List<int>.from(existing.lyepoc);
      prevRepoc = List<int>.from(existing.repoc);
      prevCepoc = List<int>.from(existing.cepoc);
      prevPpoc = List<int>.from(existing.ppoc);
      poc = existing;
    } else {
      poc = headerInfo.getNewPOC();
    }

    final totalChanges = existingChanges + newChanges;
    poc
      ..lpoc = lpoc
      ..rspoc = List<int>.filled(totalChanges, 0, growable: false)
      ..cspoc = List<int>.filled(totalChanges, 0, growable: false)
      ..lyepoc = List<int>.filled(totalChanges, 0, growable: false)
      ..repoc = List<int>.filled(totalChanges, 0, growable: false)
      ..cepoc = List<int>.filled(totalChanges, 0, growable: false)
      ..ppoc = List<int>.filled(totalChanges, 0, growable: false);

    final segments = List<List<int>>.generate(
      totalChanges,
      (_) => List<int>.filled(6, 0, growable: false),
      growable: false,
    );

    for (var i = 0; i < existingChanges; i++) {
      segments[i][0] = prevRspoc[i];
      segments[i][1] = prevCspoc[i];
      segments[i][2] = prevLyepoc[i];
      segments[i][3] = prevRepoc[i];
      segments[i][4] = prevCepoc[i];
      segments[i][5] = prevPpoc[i];

      poc
        ..rspoc[i] = prevRspoc[i]
        ..cspoc[i] = prevCspoc[i]
        ..lyepoc[i] = prevLyepoc[i]
        ..repoc[i] = prevRepoc[i]
        ..cepoc[i] = prevCepoc[i]
        ..ppoc[i] = prevPpoc[i];
    }

    for (var idx = existingChanges; idx < totalChanges; idx++) {
      final rspoc = view.getUint8(offset);
      offset += 1;

      final cspoc = useShort ? view.getUint16(offset) : view.getUint8(offset);
      offset += useShort ? 2 : 1;

      final lyepoc = view.getUint16(offset);
      offset += 2;
      if (lyepoc < 1) {
        throw ArgumentError(
          'LYEpoc must be >= 1 in POC marker (tile=$tileIdx tile-part=$tilePartIdx change=${idx - existingChanges})',
        );
      }

      final repoc = view.getUint8(offset);
      offset += 1;
      if (repoc <= rspoc) {
        throw ArgumentError(
          'REpoc must be greater than RSpoc in POC marker (tile=$tileIdx tile-part=$tilePartIdx change=${idx - existingChanges})',
        );
      }

      final rawCepoc = useShort ? view.getUint16(offset) : view.getUint8(offset);
      offset += useShort ? 2 : 1;
      final cepoc = rawCepoc == 0 ? 0 : rawCepoc;
      if (cepoc <= cspoc) {
        throw ArgumentError(
          'CEpoc must be greater than CSpoc in POC marker (tile=$tileIdx tile-part=$tilePartIdx change=${idx - existingChanges})',
        );
      }

      final ppoc = view.getUint8(offset);
      offset += 1;

      segments[idx][0] = rspoc;
      segments[idx][1] = cspoc;
      segments[idx][2] = lyepoc;
      segments[idx][3] = repoc;
      segments[idx][4] = cepoc;
      segments[idx][5] = ppoc;

      poc
        ..rspoc[idx] = rspoc
        ..cspoc[idx] = cspoc
        ..lyepoc[idx] = lyepoc
        ..repoc[idx] = repoc
        ..cepoc[idx] = cepoc
        ..ppoc[idx] = ppoc;
    }

    if (isMainHeader) {
      headerInfo.poc['main'] = poc;
      decSpec.pcs.setDefault(segments);
    } else {
      headerInfo.poc['t$tileIdx'] = poc;
      decSpec.pcs.setTileDef(tileIdx, segments);
    }
  }

  void registerTilePartLength(int tileIdx, int tilePartIdx, int length) {
    if (tileIdx < 0 || tilePartIdx < 0) {
      throw ArgumentError('Tile index and tile-part index must be non-negative');
    }
    final tileMap = _tilePartInfo.putIfAbsent(tileIdx, () => <int, _TilePartInfo>{});
    final info = tileMap.putIfAbsent(tilePartIdx, () => _TilePartInfo());
    info.length = length;

    while (nTileParts.length <= tileIdx) {
      nTileParts.add(0);
    }
    nTileParts[tileIdx] = math.max(nTileParts[tileIdx], tileMap.length);
    _packedHeadersDirty = true;
  }

  int? getTileTotalLength(int tileIdx) {
    final tileMap = _tilePartInfo[tileIdx];
    if (tileMap == null || tileMap.isEmpty) {
      return null;
    }
    var total = 0;
    for (final entry in tileMap.values) {
      final length = entry.length;
      if (length == null || length == 0) {
        return null;
      }
      total += length;
    }
    return total;
  }

  List<int>? getTilePartLengths(int tileIdx) {
    final tileMap = _tilePartInfo[tileIdx];
    if (tileMap == null || tileMap.isEmpty) {
      return null;
    }
    final ordered = tileMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final lengths = <int>[];
    for (final entry in ordered) {
      final length = entry.value.length;
      if (length == null) {
        return null;
      }
      lengths.add(length);
    }
    return lengths;
  }

  void registerPackedPacketHeaders(int tileIdx, Uint8List data) {
    if (tileIdx < 0) {
      throw ArgumentError('Tile index must be non-negative');
    }
    _packedHeaders[tileIdx] = Uint8List.fromList(data);
    decSpec.pphs.setTileDef(tileIdx, true);
  }

  Uint8List? getPackedPacketHeaders(int tileIdx) {
    _ensurePackedPacketHeadersResolved();
    final data = _packedHeaders[tileIdx];
    if (data == null) {
      return null;
    }
    return Uint8List.fromList(data);
  }

  void parseSotMarker(Uint8List markerPayload) {
    if (markerPayload.length < 10) {
      throw ArgumentError('SOT marker payload must be at least 10 bytes');
    }

    final view = ByteData.view(
      markerPayload.buffer,
      markerPayload.offsetInBytes,
      markerPayload.lengthInBytes,
    );

    final lsot = view.getUint16(0);
    if (lsot != 10) {
      throw ArgumentError('Invalid SOT marker length: $lsot');
    }

    final tileIdx = view.getUint16(2);
    final tilePartLength = view.getUint32(4);
    final tilePartIdx = view.getUint8(8);
    final declaredTileParts = view.getUint8(9);

    final sot = headerInfo.getNewSOT()
      ..lsot = lsot
      ..isot = tileIdx
      ..psot = tilePartLength
      ..tpsot = tilePartIdx
      ..tnsot = declaredTileParts;
    headerInfo.sot['t${tileIdx}_tp$tilePartIdx'] = sot;

    registerTilePartLength(tileIdx, tilePartIdx, tilePartLength);

    while (nTileParts.length <= tileIdx) {
      nTileParts.add(0);
    }
    if (declaredTileParts != 0) {
      nTileParts[tileIdx] = math.max(nTileParts[tileIdx], declaredTileParts);
    }

    _packedHeadersDirty = true;
  }

  void parsePpmMarker(Uint8List markerPayload) {
    if (markerPayload.length < 3) {
      throw ArgumentError('PPM marker payload must be at least 3 bytes');
    }

    final view = ByteData.view(
      markerPayload.buffer,
      markerPayload.offsetInBytes,
      markerPayload.lengthInBytes,
    );

    final lppm = view.getUint16(0);
    if (lppm < 3 || lppm > markerPayload.length) {
      throw ArgumentError('Invalid PPM marker length: $lppm');
    }

    final zppm = view.getUint8(2);
    final dataLength = lppm - 3;
    if (markerPayload.length < 3 + dataLength) {
      throw ArgumentError('PPM marker truncated: expected ${3 + dataLength} bytes');
    }

    final data = markerPayload.sublist(3, 3 + dataLength);

    while (_ppmMarkerData.length <= zppm) {
      _ppmMarkerData.add(null);
    }
    _ppmMarkerData[zppm] = Uint8List.fromList(data);
    decSpec.pphs.setDefault(true);
    _ppmSeen = true;
    _packedHeadersDirty = true;
  }

  void parsePptMarker(
    Uint8List markerPayload, {
    required int tileIdx,
    required int tilePartIdx,
  }) {
    if (markerPayload.length < 3) {
      throw ArgumentError('PPT marker payload must be at least 3 bytes');
    }

    final view = ByteData.view(
      markerPayload.buffer,
      markerPayload.offsetInBytes,
      markerPayload.lengthInBytes,
    );

    final lppt = view.getUint16(0);
    if (lppt < 3 || lppt > markerPayload.length) {
      throw ArgumentError('Invalid PPT marker length: $lppt');
    }

    final zppt = view.getUint8(2);
    final dataLength = lppt - 3;
    if (markerPayload.length < 3 + dataLength) {
      throw ArgumentError('PPT marker truncated: expected ${3 + dataLength} bytes');
    }

    final data = markerPayload.sublist(3, 3 + dataLength);
    final tileMap = _tilePartInfo.putIfAbsent(tileIdx, () => <int, _TilePartInfo>{});
    final info = tileMap.putIfAbsent(tilePartIdx, () => _TilePartInfo());
    info.pptSegments[zppt] = Uint8List.fromList(data);
    decSpec.pphs.setTileDef(tileIdx, true);
    _packedHeadersDirty = true;
  }

  void setTileOfTileParts(int tileIdx) {
    _tilePartTiles.add(tileIdx);
    _packedHeadersDirty = true;
  }

  void _ensurePackedPacketHeadersResolved() {
    if (!_packedHeadersDirty) {
      return;
    }

    final builders = <int, BytesBuilder>{};

    if (_ppmSeen && _ppmMarkerData.isNotEmpty) {
      final ppmData = _assemblePpmPayload();
      if (ppmData != null) {
        if (_tilePartTiles.isEmpty) {
          throw StateError('PPM markers parsed but tile-part order is unknown');
        }
        final view = ByteData.view(ppmData.buffer, ppmData.offsetInBytes, ppmData.lengthInBytes);
        var offset = 0;
        for (final tile in _tilePartTiles) {
          if (offset + 4 > ppmData.length) {
            throw StateError('Insufficient PPM data for tile part sequence');
          }
          final length = view.getUint32(offset);
          offset += 4;
          if (length < 0) {
            throw StateError('Negative packet header length encountered in PPM data');
          }
          if (offset + length > ppmData.length) {
            throw StateError('PPM segment overruns payload while assigning headers');
          }
          final builder = builders.putIfAbsent(tile, () => BytesBuilder());
          if (length > 0) {
            builder.add(ppmData.sublist(offset, offset + length));
          }
          offset += length;
        }
        if (offset != ppmData.length) {
          // Allow trailing padding but keep track for debugging.
        }
      }
    } else {
      _assemblePptHeaders(builders);
    }

    builders.forEach((tile, builder) {
      if (_packedHeaders.containsKey(tile) && _packedHeaders[tile]!.isNotEmpty) {
        return;
      }
      _packedHeaders[tile] = builder.toBytes();
    });

    _packedHeadersDirty = false;
  }

  Uint8List? _assemblePpmPayload() {
    if (_ppmMarkerData.isEmpty) {
      return null;
    }
    final ordered = <Uint8List>[];
    for (var index = 0; index < _ppmMarkerData.length; index++) {
      final segment = _ppmMarkerData[index];
      if (segment == null) {
        throw StateError('Missing PPM marker segment at index $index');
      }
      ordered.add(segment);
    }
    if (ordered.isEmpty) {
      return null;
    }
    final builder = BytesBuilder();
    for (final segment in ordered) {
      builder.add(segment);
    }
    return builder.toBytes();
  }

  void _assemblePptHeaders(Map<int, BytesBuilder> builders) {
    if (_tilePartInfo.isEmpty) {
      return;
    }
    _tilePartInfo.forEach((tileIdx, tileParts) {
      final builder = builders.putIfAbsent(tileIdx, () => BytesBuilder());
      final orderedParts = tileParts.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final partEntry in orderedParts) {
        final segments = partEntry.value.pptSegments.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final segment in segments) {
          builder.add(segment.value);
        }
      }
    });
  }
}

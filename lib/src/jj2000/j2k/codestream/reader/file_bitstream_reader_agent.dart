part of 'bitstream_reader_agent.dart';

typedef _CodeBlockGrid =
    List<List<List<List<List<CBlkInfo?>?>?>?>?>;

class _ProgressionSegment {
  const _ProgressionSegment({
    required this.progression,
    required this.layerEnd,
    required this.resStart,
    required this.resEnd,
    required this.compStart,
    required this.compEnd,
  });

  final int progression;
  final int layerEnd;
  final int resStart;
  final int resEnd;
  final int compStart;
  final int compEnd;
}

/// Stub port of JJ2000's [FileBitstreamReaderAgent].
///
/// The original implementation is responsible for parsing tile-part headers
/// from a JPEG 2000 codestream and exposing coded code-block data on demand.
/// Porting that logic is non-trivial; for now this class only wires the
/// constructor parameters and marks the pending work.
class FileBitstreamReaderAgent extends BitstreamReaderAgent {
  static final Map<int, int> _debugCblkPreviewCounts = <int, int>{};

  FileBitstreamReaderAgent(
    HeaderDecoder header,
    RandomAccessIO input,
    DecoderSpecs decoderSpecs,
    ParameterList parameters,
    bool codestreamInfo,
    HeaderInfo headerInfo,
    {PktDecoder Function(FileBitstreamReaderAgent agent)? pktDecoderFactory}
  )   : _input = input,
        _parameters = parameters,
        _codestreamInfo = codestreamInfo,
        _headerInfo = headerInfo,
        super(header, decoderSpecs) {
    final truncation = _parameters.getParameter('trunc');
    final isTruncMode = truncation == 'on';
    final maxCbParam = _parameters.getParameter('ncb_quit');
    final maxCodeBlocks = maxCbParam == null ? -1 : int.tryParse(maxCbParam) ?? -1;
    _pktDecoder = pktDecoderFactory?.call(this) ??
        PktDecoder(decoderSpecs, header, input, this, isTruncMode, maxCodeBlocks);
      _initialiseTargetResolution();
  }

  final RandomAccessIO _input;
  final ParameterList _parameters;
  final bool _codestreamInfo;
  final HeaderInfo _headerInfo;

  late final PktDecoder _pktDecoder;

  _CodeBlockGrid? cbI;
  int lQuit = -1;

  void _initialiseTargetResolution() {
    final minAvailable = decSpec.dls.getMin();
    final resParam = _parameters.getParameter('res');
    if (resParam == null) {
      targetRes = minAvailable;
      return;
    }

    final parsed = int.tryParse(resParam);
    if (parsed == null) {
      throw ArgumentError(
        "Invalid resolution level index ('-res' option) $resParam",
      );
    }
    if (parsed < 0) {
      throw ArgumentError('Resolution level index cannot be negative: $parsed');
    }
    if (parsed > minAvailable) {
      FacilityManager.getMsgLogger().printmsg(
        MsgLogger.warning,
        'Specified resolution level ($parsed) exceeds the available maximum ($minAvailable); clamping to $minAvailable.',
      );
      targetRes = minAvailable;
      return;
    }

    targetRes = parsed;
  }

  bool Function(
    int layer,
    int resolution,
    int component,
    int precinct,
    List<int> remainingBytes,
  )? _packetOverride;
  int _packetOverrideCount = 0;
  int _packetOverrideInvocations = 0;

  ParameterList get parameters => _parameters;
  RandomAccessIO get input => _input;
  bool get codestreamInfo => _codestreamInfo;
  HeaderInfo get headerInfo => _headerInfo;

  @override
  void setTile(int x, int y) {
    if (x < 0 || y < 0 || x >= ntX || y >= ntY) {
      throw ArgumentError('Invalid tile coordinates: ($x,$y)');
    }

    ctX = x;
    ctY = y;

    final ctox = x == 0 ? ax : px + x * ntW;
    final ctoy = y == 0 ? ay : py + y * ntH;

    for (var comp = nc - 1; comp >= 0; comp--) {
      final subX = hd.getCompSubsX(comp);
      final subY = hd.getCompSubsY(comp);
      culx[comp] = (ctox + subX - 1) ~/ subX;
      culy[comp] = (ctoy + subY - 1) ~/ subY;
      offX[comp] = (px + x * ntW + subX - 1) ~/ subX;
      offY[comp] = (py + y * ntH + subY - 1) ~/ subY;
    }

    final tileIdx = getTileIdx();
    for (var comp = 0; comp < nc; comp++) {
      derived[comp] = decSpec.qts.isDerived(tileIdx, comp);

      final quantParams = decSpec.qsss.getTileCompVal(tileIdx, comp);
      if (quantParams == null) {
        throw StateError('Missing quantization step sizes for tile=$tileIdx component=$comp');
      }
      params[comp] = quantParams;

      final guardBitsValue = decSpec.gbs.getTileCompVal(tileIdx, comp);
      if (guardBitsValue == null) {
        throw StateError('Missing guard bits for tile=$tileIdx component=$comp');
      }
      guardBits[comp] = guardBitsValue;

      final maxDecompLevels = decSpec.dls.getTileCompVal(tileIdx, comp);
      if (maxDecompLevels == null) {
        throw StateError('Missing decomposition levels for tile=$tileIdx component=$comp');
      }
      mdl[comp] = maxDecompLevels;

      final hFilters = decSpec.wfs.getHFilters(tileIdx, comp).cast<WaveletFilter>();
      final vFilters = decSpec.wfs.getVFilters(tileIdx, comp).cast<WaveletFilter>();

      subbTrees[comp] = SubbandSyn.tree(
        getTileCompWidth(tileIdx, comp, maxDecompLevels),
        getTileCompHeight(tileIdx, comp, maxDecompLevels),
        getResULX(comp, maxDecompLevels),
        getResULY(comp, maxDecompLevels),
        maxDecompLevels,
        hFilters,
        vFilters,
      );

      final tree = subbTrees[comp];
      if (tree == null) {
        throw StateError('Failed to initialise subband tree for tile=$tileIdx component=$comp');
      }
      initSubbandsFields(comp, tree);
    }

    _decodeTilePackets(tileIdx);
  }

  @override
  void nextTile() {
    if (ctX == ntX - 1 && ctY == ntY - 1) {
      throw StateError('Already at the last tile');
    }
    if (ctX < ntX - 1) {
      setTile(ctX + 1, ctY);
    } else {
      setTile(0, ctY + 1);
    }
  }

  @override
  int getNomRangeBits(int component) {
    if (component < 0 || component >= nc) {
      throw ArgumentError('Component index out of range: $component');
    }
    final tree = subbTrees[component];
    if (tree == null) {
      throw StateError('Subband tree not initialized for component $component');
    }
    return tree.magBits;
  }

  @override
  DecLyrdCBlk getCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    int firstLayer,
    int numLayers,
    DecLyrdCBlk? block,
  ) {
    final tileIndex = getTileIdx();
    final blockGrid = cbI;
    if (blockGrid == null) {
      throw StateError('Code-block metadata not initialised for tile $tileIndex');
    }

    final totalLayers = decSpec.nls.getTileDef(tileIndex);
    if (totalLayers == null) {
      throw StateError('Number of layers undefined for tile $tileIndex');
    }

    var layersRequested = numLayers;
    if (layersRequested < 0) {
      layersRequested = totalLayers - firstLayer + 1;
    }

    if (lQuit != -1 && firstLayer + layersRequested > lQuit) {
      layersRequested = lQuit - firstLayer;
    }

    if (firstLayer < 1 || firstLayer > totalLayers || firstLayer + layersRequested - 1 > totalLayers) {
      throw ArgumentError(
        'Invalid layer range request (tile=$tileIndex component=$component fl=$firstLayer nl=$layersRequested)',
      );
    }

    final resolution = subband.resLvl;
    final subbandIdx = subband.sbandIdx;

    CBlkInfo? requested;
    try {
      final compLevels = blockGrid[component];
      if (compLevels == null) {
        throw ArgumentError();
      }
      final resBands = compLevels[resolution];
      if (resBands == null) {
        throw ArgumentError();
      }
      final bandBlocks = resBands[subbandIdx];
      if (bandBlocks == null) {
        throw ArgumentError();
      }
      final rowBlocks = bandBlocks[verticalCodeBlockIndex];
      if (rowBlocks == null) {
        throw ArgumentError();
      }
      requested = rowBlocks[horizontalCodeBlockIndex];
    } on RangeError catch (_) {
      throw ArgumentError(
        'Code-block (t:$tileIndex, c:$component, r:$resolution, s:$subbandIdx, '
        '${verticalCodeBlockIndex}x$horizontalCodeBlockIndex) not found in codestream',
      );
    } on ArgumentError catch (_) {
      throw ArgumentError(
        'Code-block (t:$tileIndex, c:$component, r:$resolution, s:$subbandIdx, '
        '${verticalCodeBlockIndex}x$horizontalCodeBlockIndex) not found in bit stream',
      );
    }

    final result = block ?? DecLyrdCBlk();
    result
      ..m = verticalCodeBlockIndex
      ..n = horizontalCodeBlockIndex
      ..nl = 0
      ..dl = 0
      ..nTrunc = 0
      ..prog = false
      ..ftpIdx = 0;

    if (requested == null) {
      result
        ..skipMSBP = 0
        ..w = 0
        ..h = 0
        ..ulx = 0
        ..uly = 0;
      return result;
    }

    if (component > 0 && layersRequested > 0) {
      final previewCount = _debugCblkPreviewCounts.putIfAbsent(component, () => 0);
      if (previewCount < 6) {
        _debugCblkPreviewCounts[component] = previewCount + 1;
        final displayCount = math.min(layersRequested, requested.ntp.length);
        final ntpSummary = requested.ntp.take(displayCount).join(',');
        final lenSummary = requested.len.take(displayCount).join(',');
        print(
          'FileBitstreamReaderAgent cblk meta: tile=$tileIndex comp=$component res=$resolution '
          'band=$subbandIdx m=$verticalCodeBlockIndex n=$horizontalCodeBlockIndex '
          'len=[$lenSummary] ntp=[$ntpSummary] msbSkipped=${requested.msbSkipped}',
        );
      }
    }

    result
      ..skipMSBP = requested.msbSkipped
      ..ulx = requested.ulx
      ..uly = requested.uly
      ..w = requested.w
      ..h = requested.h;

    var layerCursor = 0;
    while (layerCursor < requested.len.length && requested.len[layerCursor] == 0) {
      result.ftpIdx += requested.ntp[layerCursor];
      layerCursor++;
    }

    if (layersRequested > 0) {
      for (var layer = firstLayer - 1; layer < firstLayer + layersRequested - 1; layer++) {
        result.nl++;
        result.dl += requested.len[layer];
        result.nTrunc += requested.ntp[layer];
      }
    }

    final options = decSpec.ecopts.getTileCompVal(tileIndex, component) ?? 0;
    var terminatedSegments = 1;
    if ((options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0) {
      terminatedSegments = result.nTrunc - result.ftpIdx;
    } else if ((options & StdEntropyCoderOptions.OPT_BYPASS) != 0) {
      if (result.nTrunc <= StdEntropyCoderOptions.FIRST_BYPASS_PASS_IDX) {
        terminatedSegments = 1;
      } else {
        terminatedSegments = 1;
        for (var tpIdx = result.ftpIdx; tpIdx < result.nTrunc; tpIdx++) {
          if (tpIdx >= StdEntropyCoderOptions.FIRST_BYPASS_PASS_IDX - 1) {
            final passType =
                (tpIdx + StdEntropyCoderOptions.NUM_EMPTY_PASSES_IN_MS_BP) % StdEntropyCoderOptions.NUM_PASSES;
            if (passType == 1 || passType == 2) {
              terminatedSegments++;
            }
          }
        }
      }
    }

    if (terminatedSegments <= 0) {
      terminatedSegments = 1;
    }

    if (result.dl > 0) {
      var data = result.data;
      if (data == null || data.length < result.dl) {
        data = Uint8List(result.dl);
        result.data = data;
      }
    } else {
      result.data = result.dl == 0 ? Uint8List(0) : result.data;
    }

    if (terminatedSegments > 1) {
      final current = result.tsLengths;
      if (current == null || current.length < terminatedSegments) {
        result.tsLengths = List<int>.filled(terminatedSegments, 0, growable: false);
      } else if ((options & (StdEntropyCoderOptions.OPT_BYPASS | StdEntropyCoderOptions.OPT_TERM_PASS)) ==
          StdEntropyCoderOptions.OPT_BYPASS) {
        ArrayUtil.intArraySet(current, 0);
      }
    } else if (result.tsLengths != null && result.tsLengths!.isNotEmpty) {
      result.tsLengths![0] = 0;
    }

    if (result.dl == 0) {
      if (terminatedSegments == 1 && result.tsLengths != null && result.tsLengths!.isNotEmpty) {
        result.tsLengths![0] = 0;
      }
      return result;
    }

    var dataIndex = -1;
    var truncationIndex = result.ftpIdx;
    var cumulativeTruncation = result.ftpIdx;
    var terminatedIndex = 0;

    final tsLengths = result.tsLengths;

    for (var layer = firstLayer - 1; layer < firstLayer + layersRequested - 1; layer++) {
      cumulativeTruncation += requested.ntp[layer];
      final layerLength = requested.len[layer];
      if (layerLength == 0) {
        continue;
      }

      final data = result.data;
      if (data == null) {
        throw StateError('Allocated code-block buffer missing for tile $tileIndex');
      }
      final payload = requested.body[layer];
      if (payload != null) {
        if (payload.length != layerLength) {
          throw StateError(
            'Stored packet body length mismatch for tile $tileIndex layer ${layer + 1}: '
            'expected $layerLength, found ${payload.length}',
          );
        }
        if (payload.isNotEmpty) {
          data.setRange(dataIndex + 1, dataIndex + 1 + payload.length, payload);
        }
      } else {
        _input.seek(requested.off[layer]);
        _input.readFully(data, dataIndex + 1, layerLength);
      }
      dataIndex += layerLength;

      if (terminatedSegments == 1 || tsLengths == null) {
        continue;
      }

      if ((options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0) {
        final segLengths = requested.segLen[layer];
        for (var j = 0; truncationIndex < cumulativeTruncation; j++, truncationIndex++) {
          tsLengths[terminatedIndex++] =
              segLengths != null && j < segLengths.length ? segLengths[j] : requested.len[layer];
        }
      } else {
        final segLengths = requested.segLen[layer];
        var segCursor = 0;
        for (; truncationIndex < cumulativeTruncation; truncationIndex++) {
          if (truncationIndex >= StdEntropyCoderOptions.FIRST_BYPASS_PASS_IDX - 1) {
            final passType =
                (truncationIndex + StdEntropyCoderOptions.NUM_EMPTY_PASSES_IN_MS_BP) % StdEntropyCoderOptions.NUM_PASSES;
            if (passType != 0) {
              if (segLengths != null && segCursor < segLengths.length) {
                tsLengths[terminatedIndex] += segLengths[segCursor];
                requested.len[layer] -= segLengths[segCursor];
                terminatedIndex++;
                segCursor++;
              } else {
                tsLengths[terminatedIndex] += requested.len[layer];
                requested.len[layer] = 0;
                terminatedIndex++;
              }
            }
          }
        }

        if (segLengths != null && segCursor < segLengths.length) {
          tsLengths[terminatedIndex] += segLengths[segCursor];
          requested.len[layer] -= segLengths[segCursor];
        } else if (terminatedIndex < terminatedSegments) {
          tsLengths[terminatedIndex] += requested.len[layer];
          requested.len[layer] = 0;
        }
      }
    }

    if (terminatedSegments == 1 && tsLengths != null && tsLengths.isNotEmpty) {
      tsLengths[0] = result.dl;
    }

    final lastLayer = firstLayer + layersRequested - 1;
    if (lastLayer < totalLayers - 1) {
      for (var layer = lastLayer + 1; layer < totalLayers; layer++) {
        if (requested.len[layer] != 0) {
          result.prog = true;
          break;
        }
      }
    }

    return result;
  }

  void _decodeTilePackets(int tileIdx) {
    final numLayersValue = decSpec.nls.getTileDef(tileIdx) ?? decSpec.nls.getDefault();
    if (numLayersValue == null) {
      throw StateError('Number of layers undefined for tile $tileIdx');
    }
    final maxLevels = List<int>.generate(
      nc,
      (component) {
        final value = decSpec.dls.getTileCompVal(tileIdx, component);
        if (value == null) {
          throw StateError('Missing decomposition levels for tile=$tileIdx component=$component');
        }
        return value;
      },
      growable: false,
    );

    var packedHeaders = decSpec.pphs.getTileDef(tileIdx) ?? false;
    Uint8List? packedHeaderData;
    if (packedHeaders) {
      packedHeaderData = hd.getPackedPacketHeaders(tileIdx);
      if (packedHeaderData == null || packedHeaderData.isEmpty) {
        packedHeaders = false;
      }
    } else {
      final candidate = hd.getPackedPacketHeaders(tileIdx);
      if (candidate != null && candidate.isNotEmpty) {
        packedHeaders = true;
        packedHeaderData = candidate;
      }
    }

    if (numLayersValue <= 0) {
      cbI = _pktDecoder.restart(nc, maxLevels, 0, cbI, packedHeaders, null);
      return;
    }

    final declaredTiles = _headerInfo.siz?.getNumTiles() ?? nt;
    final listSize = math.max(declaredTiles, tileIdx + 1);
    final remainingBytes = List<int>.filled(listSize > 0 ? listSize : 1, 0x7fffffff, growable: false);
    final tileBudget = hd.getTileTotalLength(tileIdx);
    final tilePartLengths = hd.getTilePartLengths(tileIdx);
    final tilePartBodyLengths = hd.getTilePartBodyLengths(tileIdx);
    final tilePartOffsets = hd.getTilePartDataOffsets(tileIdx);

    final budgets = <int>[];
    if (tilePartBodyLengths != null && tilePartBodyLengths.isNotEmpty) {
      for (final length in tilePartBodyLengths) {
        budgets.add(_normalizeTilePartBudget(length));
      }
    } else if (tilePartLengths != null && tilePartLengths.isNotEmpty) {
      for (final length in tilePartLengths) {
        budgets.add(_normalizeTilePartBudget(length));
      }
    } else if (tileBudget != null) {
      budgets.add(_normalizeTilePartBudget(tileBudget));
    }

    if (budgets.isEmpty) {
      budgets.add(0x7fffffff);
    }

    if (tilePartOffsets != null && tilePartOffsets.isNotEmpty) {
      _input.seek(tilePartOffsets.first);
    }

    remainingBytes[tileIdx] = budgets.first;

    final grid = _pktDecoder.restart(
      nc,
      maxLevels,
      numLayersValue,
      cbI,
      packedHeaders,
      packedHeaders ? packedHeaderData : null,
    );

    cbI = grid;
    _pktDecoder.syncHeaderReader();

    final maxResolutionsInTile = maxLevels.isEmpty ? 0 : maxLevels.reduce(math.max) + 1;
    final precinctGrid = _buildPrecinctGridCache(maxLevels, maxResolutionsInTile);

    final segments = _buildProgressionSegments(tileIdx, numLayersValue, maxLevels, maxResolutionsInTile);
    final layerStarts = List<List<int>>.generate(
      nc,
      (component) => List<int>.filled(maxLevels[component] + 1, 0, growable: false),
      growable: false,
    );

    var tilePartIdx = 0;
    var segmentIdx = 0;
    while (segmentIdx < segments.length) {
      final segment = segments[segmentIdx];
      final truncated = _decodeSegment(
        segment,
        layerStarts,
        maxLevels,
        maxResolutionsInTile,
        numLayersValue,
        remainingBytes,
        grid,
        precinctGrid,
      );
      if (truncated) {
        final exhausted = remainingBytes[tileIdx] <= 0;
        if (exhausted && tilePartIdx + 1 < budgets.length) {
          tilePartIdx++;
          remainingBytes[tileIdx] = budgets[tilePartIdx];
          if (tilePartOffsets != null && tilePartIdx < tilePartOffsets.length) {
            _input.seek(tilePartOffsets[tilePartIdx]);
          }
          _pktDecoder.syncHeaderReader();
          continue;
        }
        break;
      }
      _updateLayerStarts(layerStarts, segment, numLayersValue, maxLevels);
      segmentIdx++;
    }
  }

  int _normalizeTilePartBudget(int length) {
    if (length <= 0) {
      return 0x7fffffff;
    }
    return length;
  }

  List<List<Coord?>> _buildPrecinctGridCache(List<int> maxLevels, int maxResolutions) {
    return List<List<Coord?>>.generate(
      nc,
      (component) => List<Coord?>.generate(
        maxResolutions,
        (resolution) {
          if (resolution > maxLevels[component]) {
            return null;
          }
          final numPrecincts = _pktDecoder.getNumPrecinct(component, resolution);
          if (numPrecincts == 0) {
            return null;
          }
          final size = _pktDecoder.getPrecinctGridSize(component, resolution);
          if (size.x == 0 || size.y == 0) {
            return null;
          }
          return size;
        },
        growable: false,
      ),
      growable: false,
    );
  }

  bool _decodeLrcp(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    final layerEnd = math.min(segment.layerEnd, numLayers);
    final resStart = math.max(segment.resStart, 0);
    final resEnd = math.min(segment.resEnd, maxResolutions);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    final minLayer = _computeMinLayerStart(layerStarts, segment, maxLevels, numLayers);

    for (var layer = minLayer; layer < layerEnd; layer++) {
      for (var resolution = resStart; resolution < resEnd; resolution++) {
        for (var component = compStart; component < compEnd; component++) {
          if (component >= nc) {
            break;
          }
          if (resolution > maxLevels[component]) {
            continue;
          }
          final startLayer = layerStarts[component][resolution];
          if (layer < startLayer) {
            continue;
          }
          final coord = precinctGrid[component][resolution];
          if (coord == null) {
            continue;
          }
          final precinctCount = coord.x * coord.y;
          for (var precinct = 0; precinct < precinctCount; precinct++) {
            if (_processPacket(layer, resolution, component, precinct, remainingBytes, grid)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  bool _decodeRlcp(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    final layerEnd = math.min(segment.layerEnd, numLayers);
    final resStart = math.max(segment.resStart, 0);
    final resEnd = math.min(segment.resEnd, maxResolutions);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    final minLayer = _computeMinLayerStart(layerStarts, segment, maxLevels, numLayers);

    for (var resolution = resStart; resolution < resEnd; resolution++) {
      for (var layer = minLayer; layer < layerEnd; layer++) {
        for (var component = compStart; component < compEnd; component++) {
          if (component >= nc) {
            break;
          }
          if (resolution > maxLevels[component]) {
            continue;
          }
          final startLayer = layerStarts[component][resolution];
          if (layer < startLayer) {
            continue;
          }
          final coord = precinctGrid[component][resolution];
          if (coord == null) {
            continue;
          }
          final precinctCount = coord.x * coord.y;
          if (precinctCount == 0) {
            if (layerStarts[component][resolution] <= layer) {
              layerStarts[component][resolution] = layer + 1;
            }
            continue;
          }
          for (var precinct = 0; precinct < precinctCount; precinct++) {
            if (_processPacket(layer, resolution, component, precinct, remainingBytes, grid)) {
              return true;
            }
          }
          if (layerStarts[component][resolution] <= layer) {
            layerStarts[component][resolution] = layer + 1;
          }
        }
      }
    }

    return false;
  }

  bool _decodeRpcl(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    final layerEnd = math.min(segment.layerEnd, numLayers);
    final resStart = math.max(segment.resStart, 0);
    final resEnd = math.min(segment.resEnd, maxResolutions);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    final minLayer = _computeMinLayerStart(layerStarts, segment, maxLevels, numLayers);

    for (var resolution = resStart; resolution < resEnd; resolution++) {
      var maxPrecX = 0;
      var maxPrecY = 0;
      final coords = List<Coord?>.filled(nc, null, growable: false);

      for (var component = compStart; component < compEnd; component++) {
        if (component >= nc) {
          break;
        }
        if (resolution > maxLevels[component]) {
          continue;
        }
        final coord = precinctGrid[component][resolution];
        if (coord == null || coord.x == 0 || coord.y == 0) {
          coords[component] = null;
          continue;
        }
        coords[component] = coord;
        if (coord.x > maxPrecX) {
          maxPrecX = coord.x;
        }
        if (coord.y > maxPrecY) {
          maxPrecY = coord.y;
        }
      }

      if (maxPrecX == 0 || maxPrecY == 0) {
        continue;
      }

      for (var y = 0; y < maxPrecY; y++) {
        for (var x = 0; x < maxPrecX; x++) {
          for (var component = compStart; component < compEnd; component++) {
            if (component >= nc) {
              break;
            }
            final coord = coords[component];
            if (coord == null || x >= coord.x || y >= coord.y) {
              continue;
            }
            final precinct = y * coord.x + x;
            final startLayer = layerStarts[component][resolution];
            final effectiveStart = math.max(minLayer, startLayer);
            for (var layer = effectiveStart; layer < layerEnd; layer++) {
              if (_processPacket(layer, resolution, component, precinct, remainingBytes, grid)) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  bool _decodePcrl(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    final layerEnd = math.min(segment.layerEnd, numLayers);
    final resStart = math.max(segment.resStart, 0);
    final resEnd = math.min(segment.resEnd, maxResolutions);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    final minLayer = _computeMinLayerStart(layerStarts, segment, maxLevels, numLayers);

    var maxPrecX = 0;
    var maxPrecY = 0;
    for (var component = compStart; component < compEnd; component++) {
      if (component >= nc) {
        break;
      }
      final levels = precinctGrid[component];
      final compMaxRes = math.min(resEnd, maxLevels[component] + 1);
      for (var resolution = resStart; resolution < compMaxRes; resolution++) {
        final coord = levels[resolution];
        if (coord == null) {
          continue;
        }
        if (coord.x > maxPrecX) {
          maxPrecX = coord.x;
        }
        if (coord.y > maxPrecY) {
          maxPrecY = coord.y;
        }
      }
    }

    if (maxPrecX == 0 || maxPrecY == 0) {
      return false;
    }

    for (var y = 0; y < maxPrecY; y++) {
      for (var x = 0; x < maxPrecX; x++) {
        for (var component = compStart; component < compEnd; component++) {
          if (component >= nc) {
            break;
          }
          final levels = precinctGrid[component];
          final compMaxRes = math.min(resEnd, maxLevels[component] + 1);
          for (var resolution = resStart; resolution < compMaxRes; resolution++) {
            final coord = levels[resolution];
            if (coord == null || x >= coord.x || y >= coord.y) {
              continue;
            }
            final precinct = y * coord.x + x;
            final startLayer = layerStarts[component][resolution];
            final effectiveStart = math.max(minLayer, startLayer);
            for (var layer = effectiveStart; layer < layerEnd; layer++) {
              if (_processPacket(layer, resolution, component, precinct, remainingBytes, grid)) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  bool _decodeCprl(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    final layerEnd = math.min(segment.layerEnd, numLayers);
    final resStart = math.max(segment.resStart, 0);
    final resEnd = math.min(segment.resEnd, maxResolutions);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    final minLayer = _computeMinLayerStart(layerStarts, segment, maxLevels, numLayers);

    for (var component = compStart; component < compEnd; component++) {
      if (component >= nc) {
        break;
      }
      var maxPrecX = 0;
      var maxPrecY = 0;
      final levels = precinctGrid[component];
      final compMaxRes = math.min(resEnd, maxLevels[component] + 1);
      for (var resolution = resStart; resolution < compMaxRes; resolution++) {
        final coord = levels[resolution];
        if (coord == null) {
          continue;
        }
        if (coord.x > maxPrecX) {
          maxPrecX = coord.x;
        }
        if (coord.y > maxPrecY) {
          maxPrecY = coord.y;
        }
      }

      if (maxPrecX == 0 || maxPrecY == 0) {
        continue;
      }

      for (var y = 0; y < maxPrecY; y++) {
        for (var x = 0; x < maxPrecX; x++) {
          for (var resolution = resStart; resolution < compMaxRes; resolution++) {
            final coord = levels[resolution];
            if (coord == null || x >= coord.x || y >= coord.y) {
              continue;
            }
            final precinct = y * coord.x + x;
            final startLayer = layerStarts[component][resolution];
            final effectiveStart = math.max(minLayer, startLayer);
            for (var layer = effectiveStart; layer < layerEnd; layer++) {
              if (_processPacket(layer, resolution, component, precinct, remainingBytes, grid)) {
                return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  List<_ProgressionSegment> _buildProgressionSegments(
    int tileIdx,
    int numLayers,
    List<int> maxLevels,
    int maxResolutions,
  ) {
    final pocSpec = decSpec.pcs.getTileDef(tileIdx);
    if (pocSpec == null || pocSpec.isEmpty) {
      final progression =
          decSpec.pos.getTileDef(tileIdx) ?? decSpec.pos.getDefault() ?? ProgressionType.LY_RES_COMP_POS_PROG;
      return <_ProgressionSegment>[
        _ProgressionSegment(
          progression: progression,
          layerEnd: numLayers,
          resStart: 0,
          resEnd: maxResolutions,
          compStart: 0,
          compEnd: nc,
        ),
      ];
    }

    final segments = <_ProgressionSegment>[];
    for (final entry in pocSpec) {
      if (entry.length < 6) {
        throw StateError('Invalid POC specification entry: expected 6 values, got ${entry.length}');
      }
      segments.add(
        _ProgressionSegment(
          progression: entry[5],
          layerEnd: entry[2],
          resStart: entry[0],
          resEnd: entry[3],
          compStart: entry[1],
          compEnd: entry[4],
        ),
      );
    }
    return segments;
  }

  bool _decodeSegment(
    _ProgressionSegment segment,
    List<List<int>> layerStarts,
    List<int> maxLevels,
    int maxResolutions,
    int numLayers,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
    List<List<Coord?>> precinctGrid,
  ) {
    if (segment.layerEnd <= 0) {
      return false;
    }
    switch (segment.progression) {
      case ProgressionType.LY_RES_COMP_POS_PROG:
        return _decodeLrcp(segment, layerStarts, maxLevels, maxResolutions, numLayers, remainingBytes, grid, precinctGrid);
      case ProgressionType.RES_LY_COMP_POS_PROG:
        return _decodeRlcp(segment, layerStarts, maxLevels, maxResolutions, numLayers, remainingBytes, grid, precinctGrid);
      case ProgressionType.RES_POS_COMP_LY_PROG:
        return _decodeRpcl(segment, layerStarts, maxLevels, maxResolutions, numLayers, remainingBytes, grid, precinctGrid);
      case ProgressionType.POS_COMP_RES_LY_PROG:
        return _decodePcrl(segment, layerStarts, maxLevels, maxResolutions, numLayers, remainingBytes, grid, precinctGrid);
      case ProgressionType.COMP_POS_RES_LY_PROG:
        return _decodeCprl(segment, layerStarts, maxLevels, maxResolutions, numLayers, remainingBytes, grid, precinctGrid);
      default:
        throw UnsupportedError('Progression order ${segment.progression} is not supported yet');
    }
  }

  int _computeMinLayerStart(
    List<List<int>> layerStarts,
    _ProgressionSegment segment,
    List<int> maxLevels,
    int numLayers,
  ) {
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    if (compStart >= compEnd) {
      return math.min(segment.layerEnd, numLayers);
    }
    var minStart = numLayers;
    for (var component = compStart; component < compEnd; component++) {
      if (component >= nc) {
        break;
      }
      final compMaxRes = maxLevels[component];
      final resStart = math.max(segment.resStart, 0);
      final resEnd = math.min(segment.resEnd, compMaxRes + 1);
      if (resStart >= resEnd) {
        continue;
      }
      final compLayers = layerStarts[component];
      for (var resolution = resStart; resolution < resEnd; resolution++) {
        final start = compLayers[resolution];
        if (start < minStart) {
          minStart = start;
        }
      }
    }
    if (minStart == numLayers) {
      return math.min(segment.layerEnd, numLayers);
    }
    return minStart;
  }

  void _updateLayerStarts(
    List<List<int>> layerStarts,
    _ProgressionSegment segment,
    int numLayers,
    List<int> maxLevels,
  ) {
    final stopLayer = math.min(segment.layerEnd, numLayers);
    final compStart = math.max(segment.compStart, 0);
    final compEnd = math.min(segment.compEnd, nc);
    if (compStart >= compEnd) {
      return;
    }
    for (var component = compStart; component < compEnd; component++) {
      if (component >= nc) {
        break;
      }
      final compMaxRes = maxLevels[component];
      final resStart = math.max(segment.resStart, 0);
      final resEnd = math.min(segment.resEnd, compMaxRes + 1);
      if (resStart >= resEnd) {
        continue;
      }
      final compLayers = layerStarts[component];
      for (var resolution = resStart; resolution < resEnd; resolution++) {
        if (compLayers[resolution] < stopLayer) {
          compLayers[resolution] = stopLayer;
        }
      }
    }
  }

  bool _processPacket(
    int layer,
    int resolution,
    int component,
    int precinct,
    List<int> remainingBytes,
    _CodeBlockGrid grid,
  ) {
    if (_packetOverride != null) {
      if (_packetOverrideCount > 0 && _packetOverrideInvocations >= _packetOverrideCount) {
        return true;
      }
      _packetOverrideInvocations++;
      return _packetOverride!(layer, resolution, component, precinct, remainingBytes);
    }
    if (_pktDecoder.readSOPMarker(remainingBytes, precinct, component, resolution)) {
      return true;
    }

    List<List<List<CBlkInfo?>?>?>? subbandBlocks;
    if (component < grid.length) {
      final compEntry = grid[component];
      if (compEntry != null && resolution < compEntry.length) {
        subbandBlocks = compEntry[resolution];
      }
    }

    if (_pktDecoder.readPktHead(layer, resolution, component, precinct, subbandBlocks, remainingBytes)) {
      return true;
    }
    if (_pktDecoder.readPktBody(layer, resolution, component, precinct, subbandBlocks, remainingBytes)) {
      return true;
    }
    return false;
  }
  void debugSetPacketSimulation(
    int packetCount,
    bool Function(
      int layer,
      int resolution,
      int component,
      int precinct,
      List<int> remainingBytes,
    ) override,
  ) {
    _packetOverrideCount = packetCount;
    _packetOverrideInvocations = 0;
    _packetOverride = override;
  }

  void debugClearPacketSimulation() {
    _packetOverrideCount = 0;
    _packetOverride = null;
    _packetOverrideInvocations = 0;
  }
}

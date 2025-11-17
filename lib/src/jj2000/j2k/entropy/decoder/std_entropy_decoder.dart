import '../../decoder/decoder_specs.dart';
import '../../image/data_blk.dart';
import '../../image/data_blk_int.dart';
import '../../util/array_util.dart';
import '../../util/facility_manager.dart';
import '../../util/msg_logger.dart';
import '../../wavelet/subband.dart';
import '../../wavelet/synthesis/subband_syn.dart';
import '../std_entropy_coder_options.dart';
import 'byte_input_buffer.dart';
import 'byte_to_bit_input.dart';
import 'coded_cblk_data_src_dec.dart';
import 'dec_lyrd_cblk.dart';
import 'entropy_decoder.dart';
import 'mq_decoder.dart';

/// JPEG 2000 entropy decoder mirroring the JJ2000 reference implementation.
class StdEntropyDecoder extends EntropyDecoder {
  static const bool _doTiming = false;

  static const int _zcLutBits = 8;
  static const int _scLutBits = 9;
  static const int _mrLutBits = 9;

  static const int _numContexts = 19;
  static const int _rlcContext = 1;
  static const int _uniformContext = 0;
  static const int _intSignBit = 1 << 31;
  static const int _segSymbol = 10;

  static const List<int> _mqInit = <int>[
    46,
    3,
    4,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  static final List<int> _zcLutLh = _buildZcLutLh();
  static final List<int> _zcLutHl = _buildZcLutHl();
  static final List<int> _zcLutHh = _buildZcLutHh();
  static final List<int> _scLut = _buildScLut();
  static final List<int> _mrLut = _buildMrLut();

  static const int _stateSep = 16;

  static const int _stateSigR1 = 1 << 15;
  static const int _stateVisitedR1 = 1 << 14;
  static const int _stateNzCtxtR1 = 1 << 13;
  static const int _stateHlSignR1 = 1 << 12;
  static const int _stateHrSignR1 = 1 << 11;
  static const int _stateVuSignR1 = 1 << 10;
  static const int _stateVdSignR1 = 1 << 9;
  static const int _statePrevMrR1 = 1 << 8;
  static const int _stateHlR1 = 1 << 7;
  static const int _stateHrR1 = 1 << 6;
  static const int _stateVuR1 = 1 << 5;
  static const int _stateVdR1 = 1 << 4;
  static const int _stateDulR1 = 1 << 3;
  static const int _stateDurR1 = 1 << 2;
  static const int _stateDdlR1 = 1 << 1;
  static const int _stateDdrR1 = 1;

  static const int _stateSigR2 = _stateSigR1 << _stateSep;
  static const int _stateVisitedR2 = _stateVisitedR1 << _stateSep;
  static const int _stateNzCtxtR2 = _stateNzCtxtR1 << _stateSep;
  static const int _stateHlSignR2 = _stateHlSignR1 << _stateSep;
  static const int _stateHrSignR2 = _stateHrSignR1 << _stateSep;
  static const int _stateVuSignR2 = _stateVuSignR1 << _stateSep;
  static const int _stateVdSignR2 = _stateVdSignR1 << _stateSep;
  static const int _statePrevMrR2 = _statePrevMrR1 << _stateSep;
  static const int _stateHlR2 = _stateHlR1 << _stateSep;
  static const int _stateHrR2 = _stateHrR1 << _stateSep;
  static const int _stateVuR2 = _stateVuR1 << _stateSep;
  static const int _stateVdR2 = _stateVdR1 << _stateSep;
  static const int _stateDulR2 = _stateDulR1 << _stateSep;
  static const int _stateDurR2 = _stateDurR1 << _stateSep;
  static const int _stateDdlR2 = _stateDdlR1 << _stateSep;
  static const int _stateDdrR2 = _stateDdrR1 << _stateSep;

  static const int _sigMaskR1R2 = _stateSigR1 | _stateSigR2;
  static const int _vstdMaskR1R2 = _stateVisitedR1 | _stateVisitedR2;
  static const int _zcMask = (1 << 8) - 1;
  static const int _scMask = (1 << _scLutBits) - 1;
  static const int _scShiftR1 = 4;
  static const int _scShiftR2 = _scShiftR1 + _stateSep;
  static const int _scSpredShift = 31;
  static const int _mrMask = (1 << 9) - 1;
  static int _debugCounter = 0;

  StdEntropyDecoder(
    CodedCBlkDataSrcDec src,
    this.decoderSpecs,
    bool doErrorDetection,
    bool verbose,
    int mQuit,
  )   : _doErrorDetection = doErrorDetection,
        _verboseErrors = verbose,
        _mQuit = mQuit,
        super(src) {
    if (_doTiming) {
      _timings = List<int>.filled(src.getNumComps(), 0);
    }
    final maxWidth = decoderSpecs.cblks.getMaxCBlkWidth();
    final maxHeight = decoderSpecs.cblks.getMaxCBlkHeight();
    state = List<int>.filled(
      (maxWidth + 2) * (((maxHeight + 1) >> 1) + 2),
      0,
      growable: false,
    );
  }

  final DecoderSpecs decoderSpecs;
  final bool _doErrorDetection;
  final bool _verboseErrors;
  final int _mQuit;

  ByteToBitInput? _bin;
  MQDecoder? _mq;
  ByteInputBuffer? _mqInput;

  DecLyrdCBlk? _srcBlk;

  List<int>? _timings;

  late final List<int> state;

  int _options = 0;

  @override
  DataBlk getCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    DataBlk? block,
  ) {
    final tileIndex = getTileIdx();
    _srcBlk = src.getCodeBlock(
      component,
      verticalCodeBlockIndex,
      horizontalCodeBlockIndex,
      subband,
      1,
      -1,
      _srcBlk,
    );
    final currentBlock = _srcBlk;
    if (currentBlock == null) {
      throw StateError('Entropy source returned null code-block');
    }

    int start = 0;
    if (_doTiming) {
      start = DateTime.now().millisecondsSinceEpoch;
    }

    final opt = decoderSpecs.ecopts.getTileCompVal(tileIndex, component);
    _options = opt ?? 0;

    ArrayUtil.intArraySet(state, 0);

    DataBlkInt outBlk;
    if (block is DataBlkInt) {
      outBlk = block;
    } else {
      outBlk = DataBlkInt();
    }

    outBlk
      ..progressive = currentBlock.prog
      ..ulx = currentBlock.ulx
      ..uly = currentBlock.uly
      ..w = currentBlock.w
      ..h = currentBlock.h
      ..offset = 0
      ..scanw = currentBlock.w;

    var outData = outBlk.data;
    final required = currentBlock.w * currentBlock.h;
    if (outData == null || outData.length < required) {
      outData = List<int>.filled(required, 0, growable: false);
      outBlk.data = outData;
    } else {
      ArrayUtil.intArraySet(outData, 0);
    }

    if (currentBlock.nl <= 0 || currentBlock.nTrunc <= 0) {
      return outBlk;
    }

    final data = currentBlock.data;
    if (data == null) {
      throw StateError('Decoded code-block payload is missing');
    }

    final tsLengths = currentBlock.tsLengths;
    final initialSegmentLength =
      tsLengths == null || tsLengths.isEmpty ? currentBlock.dl : _segmentLength(tsLengths, 0);

    if (_debugCounter < 3) {
      _debugCounter++;
      final dataLength = data.length;
      final segments = tsLengths == null ? 'null' : tsLengths.join(',');
      print(
        'StdEntropyDecoder debug: dl=${currentBlock.dl}, dataLen=$dataLength, '
        'initialSegment=$initialSegmentLength, tsLengths=$segments',
      );
    }

    if (_mq == null) {
      _mqInput = ByteInputBuffer.view(data, 0, initialSegmentLength);
      _mq = MQDecoder(_mqInput!, _numContexts, _mqInit);
    } else {
      _mq!.nextSegment(data, 0, initialSegmentLength);
      _mq!.resetCtxts();
    }

    var errorDetected = false;
    if ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0) {
      _bin ??= ByteToBitInput(_mq!.getByteInputBuffer());
    }

    final zcLut = _selectZcLut(subband.orientation);

    var npasses = currentBlock.nTrunc;
    var curBitPlane = 30 - currentBlock.skipMSBP;

    if (_mQuit != -1 && (_mQuit * 3 - 2) < npasses) {
      npasses = _mQuit * 3 - 2;
    }

    var segmentIndex = 0;

    if (curBitPlane >= 0 && npasses > 0) {
      final isTerminated = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0 ||
          ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
              (31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP) >= curBitPlane);
      errorDetected = _cleanupPass(
        outBlk,
        _mq!,
        curBitPlane,
        state,
        zcLut,
        isTerminated,
      );
      npasses--;
      if (!errorDetected || !_doErrorDetection) {
        curBitPlane--;
      }
    }

    if (!errorDetected || !_doErrorDetection) {
      while (curBitPlane >= 0 && npasses > 0) {
        if ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
            curBitPlane < 31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP) {
          _bin!.setByteArray(null, -1, _segmentLength(tsLengths, ++segmentIndex));
          final isTerminated = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0;
          errorDetected = _rawSigProgPass(
            outBlk,
            _bin!,
            curBitPlane,
            state,
            isTerminated,
          );
          npasses--;
          if (npasses <= 0 || (errorDetected && _doErrorDetection)) {
            break;
          }

          if ((_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0) {
            _bin!.setByteArray(null, -1, _segmentLength(tsLengths, ++segmentIndex));
          }

          final isTerminatedMag = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0 ||
              ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
                  (31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP > curBitPlane));
          errorDetected = _rawMagRefPass(
            outBlk,
            _bin!,
            curBitPlane,
            state,
            isTerminatedMag,
          );
        } else {
          if ((_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0) {
            _mq!.nextSegment(null, -1, _segmentLength(tsLengths, ++segmentIndex));
          }
          final isTerminatedSig = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0;
          errorDetected = _sigProgPass(
            outBlk,
            _mq!,
            curBitPlane,
            state,
            zcLut,
            isTerminatedSig,
          );
          npasses--;
          if (npasses <= 0 || (errorDetected && _doErrorDetection)) {
            break;
          }

          if ((_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0) {
            _mq!.nextSegment(null, -1, _segmentLength(tsLengths, ++segmentIndex));
          }
          final isTerminatedMag = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0 ||
              ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
                  (31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP > curBitPlane));
          errorDetected = _magRefPass(
            outBlk,
            _mq!,
            curBitPlane,
            state,
            isTerminatedMag,
          );
        }

        npasses--;
        if (npasses <= 0 || (errorDetected && _doErrorDetection)) {
          break;
        }

        if ((_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0 ||
          ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
            curBitPlane < 31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP)) {
          _mq!.nextSegment(null, -1, _segmentLength(tsLengths, ++segmentIndex));
        }
        final isTerminatedCleanup = (_options & StdEntropyCoderOptions.OPT_TERM_PASS) != 0 ||
            ((_options & StdEntropyCoderOptions.OPT_BYPASS) != 0 &&
                (31 - StdEntropyCoderOptions.NUM_NON_BYPASS_MS_BP - currentBlock.skipMSBP) >= curBitPlane);
        errorDetected = _cleanupPass(
          outBlk,
          _mq!,
          curBitPlane,
          state,
          zcLut,
          isTerminatedCleanup,
        );
        npasses--;
        if (errorDetected && _doErrorDetection) {
          break;
        }
        curBitPlane--;
      }
    }

    if (errorDetected && _doErrorDetection) {
      if (_verboseErrors) {
        FacilityManager.getMsgLogger().printmsg(
              MsgLogger.warning,
              'Error detected at bit-plane $curBitPlane in code-block '
              '(${verticalCodeBlockIndex},${horizontalCodeBlockIndex}), '
              'sb_idx ${subband.sbandIdx}, res. level ${subband.resLvl}. Concealing...',
            );
      }
      _conceal(outBlk, curBitPlane);
    }

    if (_doTiming) {
      final stop = DateTime.now().millisecondsSinceEpoch;
      _timings![component] += stop - start;
    }

    return outBlk;
  }

  @override
  DataBlk getInternCodeBlock(
    int component,
    int verticalCodeBlockIndex,
    int horizontalCodeBlockIndex,
    SubbandSyn subband,
    DataBlk? block,
  ) =>
      getCodeBlock(component, verticalCodeBlockIndex, horizontalCodeBlockIndex, subband, block);

  static List<int> _selectZcLut(int orientation) {
    switch (orientation) {
      case Subband.wtOrientHl:
        return _zcLutHl;
      case Subband.wtOrientLh:
      case Subband.wtOrientLl:
        return _zcLutLh;
      case Subband.wtOrientHh:
        return _zcLutHh;
      default:
        throw StateError('Unsupported subband orientation: $orientation');
    }
  }

  static int _segmentLength(List<int>? lengths, int index) {
    if (lengths == null) {
      throw StateError('Missing terminated segment lengths for entropy-coded passes.');
    }
    if (index < 0 || index >= lengths.length) {
      throw RangeError.range(
        index,
        0,
        lengths.length - 1,
        'index',
        'Terminated segment length index out of bounds',
      );
    }
    return lengths[index];
  }

  bool _sigProgPass(
    DataBlkInt cblk,
    MQDecoder mq,
    int bitPlane,
    List<int> state,
    List<int> zcLut,
    bool terminated,
  ) {
    final data = cblk.data!;
    final dscanw = cblk.scanw;
    final sscanw = cblk.w + 2;
    final jstep = sscanw * StdEntropyCoderOptions.STRIPE_HEIGHT ~/ 2 - cblk.w;
    final kstep = dscanw * StdEntropyCoderOptions.STRIPE_HEIGHT - cblk.w;
    final setmask = (3 << bitPlane) >> 1;
    final nstripes = (cblk.h + StdEntropyCoderOptions.STRIPE_HEIGHT - 1) ~/ StdEntropyCoderOptions.STRIPE_HEIGHT;
    final causal = (_options & StdEntropyCoderOptions.OPT_VERT_STR_CAUSAL) != 0;

    final offUl = -sscanw - 1;
    final offUr = -sscanw + 1;
    final offDr = sscanw + 1;
    final offDl = sscanw - 1;

    var sk = cblk.offset;
    var sj = sscanw + 1;
    for (var s = nstripes - 1; s >= 0; s--, sk += kstep, sj += jstep) {
      final stripeHeight = (s != 0)
          ? StdEntropyCoderOptions.STRIPE_HEIGHT
          : cblk.h - (nstripes - 1) * StdEntropyCoderOptions.STRIPE_HEIGHT;
      final stopSk = sk + cblk.w;
      for (; sk < stopSk; sk++, sj++) {
        var j = sj;
        var csj = state[j];
        if ((((~csj) & (csj << 2)) & _sigMaskR1R2) != 0) {
          var k = sk;
          if ((csj & (_stateSigR1 | _stateNzCtxtR1)) == _stateNzCtxtR1) {
            if (mq.decodeSymbol(zcLut[csj & _zcMask]) != 0) {
              final ctxt = _scLut[(csj >>> _scShiftR1) & _scMask];
              final sym = mq.decodeSymbol(ctxt & ((1 << _scShiftR1) - 1)) ^
                  (ctxt >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              if (!causal) {
                state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
                state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              }
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                    _stateVuR2 | _stateVuSignR2;
                if (!causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 |
                      _stateVdR2 | _stateVdSignR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                if (!causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
            } else {
              csj |= _stateVisitedR1;
            }
          }
          if (stripeHeight < 2) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateNzCtxtR2)) == _stateNzCtxtR2) {
            k += dscanw;
            if (mq.decodeSymbol(zcLut[(csj >>> _stateSep) & _zcMask]) != 0) {
              final ctxt = _scLut[(csj >>> _scShiftR2) & _scMask];
              final sym = mq.decodeSymbol(ctxt & ((1 << _scShiftR1) - 1)) ^
                  (ctxt >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 |
                    _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 |
                    _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
            } else {
              csj |= _stateVisitedR2;
            }
          }
          state[j] = csj;
        }
        if (stripeHeight < 3) {
          continue;
        }
        j += sscanw;
        csj = state[j];
        if ((((~csj) & (csj << 2)) & _sigMaskR1R2) != 0) {
          var k = sk + (dscanw << 1);
          if ((csj & (_stateSigR1 | _stateNzCtxtR1)) == _stateNzCtxtR1) {
            if (mq.decodeSymbol(zcLut[csj & _zcMask]) != 0) {
              final ctxt = _scLut[(csj >>> _scShiftR1) & _scMask];
              final sym = mq.decodeSymbol(ctxt & ((1 << _scShiftR1) - 1)) ^
                  (ctxt >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
              state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2 | _stateVuSignR2;
                state[j - sscanw] |= _stateNzCtxtR2 |
                    _stateVdR2 | _stateVdSignR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
            } else {
              csj |= _stateVisitedR1;
            }
          }
          if (stripeHeight < 4) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateNzCtxtR2)) == _stateNzCtxtR2) {
            k += dscanw;
            if (mq.decodeSymbol(zcLut[(csj >>> _stateSep) & _zcMask]) != 0) {
              final ctxt = _scLut[(csj >>> _scShiftR2) & _scMask];
              final sym = mq.decodeSymbol(ctxt & ((1 << _scShiftR1) - 1)) ^
                  (ctxt >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 |
                    _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
            } else {
              csj |= _stateVisitedR2;
            }
          }
          state[j] = csj;
        }
      }
    }

    var error = false;
    if (terminated && (_options & StdEntropyCoderOptions.OPT_PRED_TERM) != 0) {
      error = mq.checkPredTerm();
    }

    if ((_options & StdEntropyCoderOptions.OPT_RESET_MQ) != 0) {
      mq.resetCtxts();
    }

    return error;
  }

  bool _rawSigProgPass(
    DataBlkInt cblk,
    ByteToBitInput bin,
    int bitPlane,
    List<int> state,
    bool terminated,
  ) {
    final data = cblk.data!;
    final dscanw = cblk.scanw;
    final sscanw = cblk.w + 2;
    final jstep = sscanw * StdEntropyCoderOptions.STRIPE_HEIGHT ~/ 2 - cblk.w;
    final kstep = dscanw * StdEntropyCoderOptions.STRIPE_HEIGHT - cblk.w;
    final setmask = (3 << bitPlane) >> 1;
    final nstripes = (cblk.h + StdEntropyCoderOptions.STRIPE_HEIGHT - 1) ~/ StdEntropyCoderOptions.STRIPE_HEIGHT;
    final causal = (_options & StdEntropyCoderOptions.OPT_VERT_STR_CAUSAL) != 0;

    final offUl = -sscanw - 1;
    final offUr = -sscanw + 1;
    final offDr = sscanw + 1;
    final offDl = sscanw - 1;

    var sk = cblk.offset;
    var sj = sscanw + 1;
    for (var s = nstripes - 1; s >= 0; s--, sk += kstep, sj += jstep) {
      final stripeHeight = (s != 0)
          ? StdEntropyCoderOptions.STRIPE_HEIGHT
          : cblk.h - (nstripes - 1) * StdEntropyCoderOptions.STRIPE_HEIGHT;
      final stopSk = sk + cblk.w;
      for (; sk < stopSk; sk++, sj++) {
        var j = sj;
        var csj = state[j];
        if ((((~csj) & (csj << 2)) & _sigMaskR1R2) != 0) {
          var k = sk;
          if ((csj & (_stateSigR1 | _stateNzCtxtR1)) == _stateNzCtxtR1) {
            if (bin.readBit() != 0) {
              final sym = bin.readBit();
              data[k] = (sym << 31) | setmask;
              if (!causal) {
                state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
                state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              }
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                    _stateVuR2 | _stateVuSignR2;
                if (!causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 |
                      _stateVdR2 | _stateVdSignR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                if (!causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
            } else {
              csj |= _stateVisitedR1;
            }
          }
          if (stripeHeight < 2) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateNzCtxtR2)) == _stateNzCtxtR2) {
            k += dscanw;
            if (bin.readBit() != 0) {
              final sym = bin.readBit();
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 |
                    _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 |
                    _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
            } else {
              csj |= _stateVisitedR2;
            }
          }
          state[j] = csj;
        }
        if (stripeHeight < 3) {
          continue;
        }
        j += sscanw;
        csj = state[j];
        if ((((~csj) & (csj << 2)) & _sigMaskR1R2) != 0) {
          var k = sk + (dscanw << 1);
          if ((csj & (_stateSigR1 | _stateNzCtxtR1)) == _stateNzCtxtR1) {
            if (bin.readBit() != 0) {
              final sym = bin.readBit();
              data[k] = (sym << 31) | setmask;
              state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
              state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                    _stateVuR2 | _stateVuSignR2;
                state[j - sscanw] |= _stateNzCtxtR2 |
                    _stateVdR2 | _stateVdSignR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
            } else {
              csj |= _stateVisitedR1;
            }
          }
          if (stripeHeight < 4) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateNzCtxtR2)) == _stateNzCtxtR2) {
            k += dscanw;
            if (bin.readBit() != 0) {
              final sym = bin.readBit();
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 |
                    _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 |
                    _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
            } else {
              csj |= _stateVisitedR2;
            }
          }
          state[j] = csj;
        }
      }
    }

    var error = false;
    if (terminated && (_options & StdEntropyCoderOptions.OPT_PRED_TERM) != 0) {
      error = bin.checkBytePadding();
    }
    return error;
  }

  bool _magRefPass(
    DataBlkInt cblk,
    MQDecoder mq,
    int bitPlane,
    List<int> state,
    bool terminated,
  ) {
    final data = cblk.data!;
    final dscanw = cblk.scanw;
    final sscanw = cblk.w + 2;
    final jstep = sscanw * StdEntropyCoderOptions.STRIPE_HEIGHT ~/ 2 - cblk.w;
    final kstep = dscanw * StdEntropyCoderOptions.STRIPE_HEIGHT - cblk.w;
    final setmask = (1 << bitPlane) >> 1;
    final resetmask = (-1) << (bitPlane + 1);
    final nstripes = (cblk.h + StdEntropyCoderOptions.STRIPE_HEIGHT - 1) ~/ StdEntropyCoderOptions.STRIPE_HEIGHT;

    var sk = cblk.offset;
    var sj = sscanw + 1;
    for (var s = nstripes - 1; s >= 0; s--, sk += kstep, sj += jstep) {
      final stripeHeight = (s != 0)
          ? StdEntropyCoderOptions.STRIPE_HEIGHT
          : cblk.h - (nstripes - 1) * StdEntropyCoderOptions.STRIPE_HEIGHT;
      final stopSk = sk + cblk.w;
      for (; sk < stopSk; sk++, sj++) {
        var j = sj;
        var csj = state[j];
        if ((((csj >>> 1) & (~csj)) & _vstdMaskR1R2) != 0) {
          var k = sk;
          if ((csj & (_stateSigR1 | _stateVisitedR1)) == _stateSigR1) {
            final sym = mq.decodeSymbol(_mrLut[csj & _mrMask]);
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
            csj |= _statePrevMrR1;
          }
          if (stripeHeight < 2) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateVisitedR2)) == _stateSigR2) {
            k += dscanw;
            final sym = mq.decodeSymbol(_mrLut[(csj >>> _stateSep) & _mrMask]);
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
            csj |= _statePrevMrR2;
          }
          state[j] = csj;
        }
        if (stripeHeight < 3) {
          continue;
        }
        j += sscanw;
        csj = state[j];
        if ((((csj >>> 1) & (~csj)) & _vstdMaskR1R2) != 0) {
          var k = sk + (dscanw << 1);
          if ((csj & (_stateSigR1 | _stateVisitedR1)) == _stateSigR1) {
            final sym = mq.decodeSymbol(_mrLut[csj & _mrMask]);
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
            csj |= _statePrevMrR1;
          }
          if (stripeHeight < 4) {
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateVisitedR2)) == _stateSigR2) {
            k += dscanw;
            final sym = mq.decodeSymbol(_mrLut[(csj >>> _stateSep) & _mrMask]);
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
            csj |= _statePrevMrR2;
          }
          state[j] = csj;
        }
      }
    }

    var error = false;
    if (terminated && (_options & StdEntropyCoderOptions.OPT_PRED_TERM) != 0) {
      error = mq.checkPredTerm();
    }
    if ((_options & StdEntropyCoderOptions.OPT_RESET_MQ) != 0) {
      mq.resetCtxts();
    }
    return error;
  }

  bool _rawMagRefPass(
    DataBlkInt cblk,
    ByteToBitInput bin,
    int bitPlane,
    List<int> state,
    bool terminated,
  ) {
    final data = cblk.data!;
    final dscanw = cblk.scanw;
    final sscanw = cblk.w + 2;
    final jstep = sscanw * StdEntropyCoderOptions.STRIPE_HEIGHT ~/ 2 - cblk.w;
    final kstep = dscanw * StdEntropyCoderOptions.STRIPE_HEIGHT - cblk.w;
    final setmask = (1 << bitPlane) >> 1;
    final resetmask = (-1) << (bitPlane + 1);
    final nstripes = (cblk.h + StdEntropyCoderOptions.STRIPE_HEIGHT - 1) ~/ StdEntropyCoderOptions.STRIPE_HEIGHT;

    var sk = cblk.offset;
    var sj = sscanw + 1;
    for (var s = nstripes - 1; s >= 0; s--, sk += kstep, sj += jstep) {
      final stripeHeight = (s != 0)
          ? StdEntropyCoderOptions.STRIPE_HEIGHT
          : cblk.h - (nstripes - 1) * StdEntropyCoderOptions.STRIPE_HEIGHT;
      final stopSk = sk + cblk.w;
      for (; sk < stopSk; sk++, sj++) {
        var j = sj;
        var csj = state[j];
        if ((((csj >>> 1) & (~csj)) & _vstdMaskR1R2) != 0) {
          var k = sk;
          if ((csj & (_stateSigR1 | _stateVisitedR1)) == _stateSigR1) {
            final sym = bin.readBit();
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
          }
          if (stripeHeight < 2) {
            continue;
          }
          if ((csj & (_stateSigR2 | _stateVisitedR2)) == _stateSigR2) {
            k += dscanw;
            final sym = bin.readBit();
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
          }
        }
        if (stripeHeight < 3) {
          continue;
        }
        j += sscanw;
        csj = state[j];
        if ((((csj >>> 1) & (~csj)) & _vstdMaskR1R2) != 0) {
          var k = sk + (dscanw << 1);
          if ((csj & (_stateSigR1 | _stateVisitedR1)) == _stateSigR1) {
            final sym = bin.readBit();
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
          }
          if (stripeHeight < 4) {
            continue;
          }
          if ((csj & (_stateSigR2 | _stateVisitedR2)) == _stateSigR2) {
            k += dscanw;
            final sym = bin.readBit();
            data[k] &= resetmask;
            data[k] |= (sym << bitPlane) | setmask;
          }
        }
      }
    }

    var error = false;
    if (terminated && (_options & StdEntropyCoderOptions.OPT_PRED_TERM) != 0) {
      error = bin.checkBytePadding();
    }
    return error;
  }

  bool _cleanupPass(
    DataBlkInt cblk,
    MQDecoder mq,
    int bitPlane,
    List<int> state,
    List<int> zcLut,
    bool terminated,
  ) {
    final data = cblk.data!;
    final dscanw = cblk.scanw;
    final sscanw = cblk.w + 2;
    final jstep = sscanw * StdEntropyCoderOptions.STRIPE_HEIGHT ~/ 2 - cblk.w;
    final kstep = dscanw * StdEntropyCoderOptions.STRIPE_HEIGHT - cblk.w;
    final one = 1 << bitPlane;
    final half = one >> 1;
    final setmask = one | half;
    final nstripes = (cblk.h + StdEntropyCoderOptions.STRIPE_HEIGHT - 1) ~/ StdEntropyCoderOptions.STRIPE_HEIGHT;
    final causal = (_options & StdEntropyCoderOptions.OPT_VERT_STR_CAUSAL) != 0;

    final offUl = -sscanw - 1;
    final offUr = -sscanw + 1;
    final offDr = sscanw + 1;
    final offDl = sscanw - 1;

    var sk = cblk.offset;
    var sj = sscanw + 1;
    for (var s = nstripes - 1; s >= 0; s--, sk += kstep, sj += jstep) {
      final stripeHeight = (s != 0)
          ? StdEntropyCoderOptions.STRIPE_HEIGHT
          : cblk.h - (nstripes - 1) * StdEntropyCoderOptions.STRIPE_HEIGHT;
      final stopSk = sk + cblk.w;
      for (; sk < stopSk; sk++, sj++) {
        var j = sj;
        var csj = state[j];
        var broken = false;
        if (csj == 0 && state[j + sscanw] == 0 && stripeHeight == StdEntropyCoderOptions.STRIPE_HEIGHT) {
          if (mq.decodeSymbol(_rlcContext) != 0) {
            var rlclen = mq.decodeSymbol(_uniformContext) << 1;
            rlclen |= mq.decodeSymbol(_uniformContext);
            var k = sk + rlclen * dscanw;
            if (rlclen > 1) {
              j += sscanw;
              csj = state[j];
            }
            if ((rlclen & 0x01) == 0) {
              final sym = mq.decodeSymbol(_scLut[(csj >>> _scShiftR1) & _scMask] & ((1 << _scShiftR1) - 1)) ^
                  (_scLut[(csj >>> _scShiftR1) & _scMask] >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              if (rlclen != 0 || !causal) {
                state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
                state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              }
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                    _stateVuR2 | _stateVuSignR2;
                if (rlclen != 0 || !causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 |
                      _stateVdR2 | _stateVdSignR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                if (rlclen != 0 || !causal) {
                  state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                }
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
              if ((rlclen >> 1) != 0) {
                broken = true;
              }
            } else {
              final lut = _scLut[(csj >>> _scShiftR2) & _scMask];
              final sym = mq.decodeSymbol(lut & ((1 << _scShiftR1) - 1)) ^ (lut >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 | _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
              state[j] = csj;
              if ((rlclen >> 1) != 0) {
                continue;
              }
              j += sscanw;
              csj = state[j];
              broken = true;
            }
          } else {
            continue;
          }
        }
        if (!broken) {
          if ((((csj >> 1) | csj) & _vstdMaskR1R2) != _vstdMaskR1R2) {
            var k = sk;
            if ((csj & (_stateSigR1 | _stateVisitedR1)) == 0) {
              if (mq.decodeSymbol(zcLut[csj & _zcMask]) != 0) {
                final lut = _scLut[(csj >>> _scShiftR1) & _scMask];
                final sym = mq.decodeSymbol(lut & ((1 << _scShiftR1) - 1)) ^ (lut >>> _scSpredShift);
                data[k] = (sym << 31) | setmask;
                if (!causal) {
                  state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
                  state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
                }
                if (sym != 0) {
                  csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                      _stateVuR2 | _stateVuSignR2;
                  if (!causal) {
                    state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2 | _stateVdSignR2;
                  }
                  state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                  state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateHrR1 | _stateHrSignR1 | _stateDurR2;
                } else {
                  csj |= _stateSigR1 | _stateVisitedR1 |
                      _stateNzCtxtR2 | _stateVuR2;
                  if (!causal) {
                    state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                  }
                  state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateHlR1 | _stateDulR2;
                  state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateHrR1 | _stateDurR2;
                }
              }
            }
            if (stripeHeight < 2) {
              csj &= ~(_stateVisitedR1 | _stateVisitedR2);
              state[j] = csj;
              continue;
            }
            if ((csj & (_stateSigR2 | _stateVisitedR2)) == 0) {
              k += dscanw;
              if (mq.decodeSymbol(zcLut[(csj >>> _stateSep) & _zcMask]) != 0) {
                final lut = _scLut[(csj >>> _scShiftR2) & _scMask];
                final sym = mq.decodeSymbol(lut & ((1 << _scShiftR1) - 1)) ^ (lut >>> _scSpredShift);
                data[k] = (sym << 31) | setmask;
                state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
                state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
                if (sym != 0) {
                  csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 |
                      _stateVdR1 | _stateVdSignR1;
                  state[j + sscanw] |= _stateNzCtxtR1 |
                      _stateVuR1 | _stateVuSignR1;
                  state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                  state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
                } else {
                  csj |= _stateSigR2 | _stateVisitedR2 |
                      _stateNzCtxtR1 | _stateVdR1;
                  state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                  state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateDdlR1 | _stateHlR2;
                  state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                      _stateDdrR1 | _stateHrR2;
                }
              }
            }
          }
          csj &= ~(_stateVisitedR1 | _stateVisitedR2);
          state[j] = csj;
          if (stripeHeight < 3) {
            continue;
          }
          j += sscanw;
          csj = state[j];
        }
        if ((((csj >> 1) | csj) & _vstdMaskR1R2) != _vstdMaskR1R2) {
          var k = sk + (dscanw << 1);
          if ((csj & (_stateSigR1 | _stateVisitedR1)) == 0) {
            if (mq.decodeSymbol(zcLut[csj & _zcMask]) != 0) {
              final lut = _scLut[(csj >>> _scShiftR1) & _scMask];
              final sym = mq.decodeSymbol(lut & ((1 << _scShiftR1) - 1)) ^ (lut >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offUl] |= _stateNzCtxtR2 | _stateDdrR2;
              state[j + offUr] |= _stateNzCtxtR2 | _stateDdlR2;
              if (sym != 0) {
                csj |= _stateSigR1 | _stateVisitedR1 | _stateNzCtxtR2 |
                    _stateVuR2 | _stateVuSignR2;
                state[j - sscanw] |= _stateNzCtxtR2 |
                    _stateVdR2 | _stateVdSignR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateHlSignR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateHrSignR1 | _stateDurR2;
              } else {
                csj |= _stateSigR1 | _stateVisitedR1 |
                    _stateNzCtxtR2 | _stateVuR2;
                state[j - sscanw] |= _stateNzCtxtR2 | _stateVdR2;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHlR1 | _stateDulR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateHrR1 | _stateDurR2;
              }
            }
          }
          if (stripeHeight < 4) {
            csj &= ~(_stateVisitedR1 | _stateVisitedR2);
            state[j] = csj;
            continue;
          }
          if ((csj & (_stateSigR2 | _stateVisitedR2)) == 0) {
            k += dscanw;
            if (mq.decodeSymbol(zcLut[(csj >>> _stateSep) & _zcMask]) != 0) {
              final lut = _scLut[(csj >>> _scShiftR2) & _scMask];
              final sym = mq.decodeSymbol(lut & ((1 << _scShiftR1) - 1)) ^ (lut >>> _scSpredShift);
              data[k] = (sym << 31) | setmask;
              state[j + offDl] |= _stateNzCtxtR1 | _stateDurR1;
              state[j + offDr] |= _stateNzCtxtR1 | _stateDulR1;
              if (sym != 0) {
                csj |= _stateSigR2 | _stateVisitedR2 | _stateNzCtxtR1 |
                    _stateVdR1 | _stateVdSignR1;
                state[j + sscanw] |= _stateNzCtxtR1 |
                    _stateVuR1 | _stateVuSignR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2 | _stateHlSignR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2 | _stateHrSignR2;
              } else {
                csj |= _stateSigR2 | _stateVisitedR2 |
                    _stateNzCtxtR1 | _stateVdR1;
                state[j + sscanw] |= _stateNzCtxtR1 | _stateVuR1;
                state[j + 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdlR1 | _stateHlR2;
                state[j - 1] |= _stateNzCtxtR1 | _stateNzCtxtR2 |
                    _stateDdrR1 | _stateHrR2;
              }
            }
          }
          csj &= ~(_stateVisitedR1 | _stateVisitedR2);
          state[j] = csj;
        }
      }
    }

    var error = false;
    if ((_options & StdEntropyCoderOptions.OPT_SEG_SYMBOLS) != 0) {
      var sym = mq.decodeSymbol(_uniformContext) << 3;
      sym |= mq.decodeSymbol(_uniformContext) << 2;
      sym |= mq.decodeSymbol(_uniformContext) << 1;
      sym |= mq.decodeSymbol(_uniformContext);
      error = sym != _segSymbol;
    } else {
      error = false;
    }

    if (terminated && (_options & StdEntropyCoderOptions.OPT_PRED_TERM) != 0) {
      error = mq.checkPredTerm();
    }

    if ((_options & StdEntropyCoderOptions.OPT_RESET_MQ) != 0) {
      mq.resetCtxts();
    }

    return error;
  }

  void _conceal(DataBlkInt cblk, int bitPlane) {
    final data = cblk.data!;
    final setmask = 1 << bitPlane;
    final resetmask = (-1) << bitPlane;

    var k = cblk.offset;
    for (var line = cblk.h - 1; line >= 0; line--) {
      final lineEnd = k + cblk.w;
      while (k < lineEnd) {
        final value = data[k];
        if ((value & resetmask & 0x7FFFFFFF) != 0) {
          data[k] = (value & resetmask) | setmask;
        } else {
          data[k] = 0;
        }
        k++;
      }
      k += cblk.scanw - cblk.w;
    }
  }

  static List<int> _buildZcLutLh() {
    final lut = List<int>.filled(1 << _zcLutBits, 0, growable: false);
    lut[0] = 2;
    for (var i = 1; i < 16; i++) {
      lut[i] = 4;
    }
    for (var i = 0; i < 4; i++) {
      lut[1 << i] = 3;
    }
    for (var i = 0; i < 16; i++) {
      lut[_stateVuR1 | i] = 5;
      lut[_stateVdR1 | i] = 5;
      lut[_stateVuR1 | _stateVdR1 | i] = 6;
    }
    lut[_stateHlR1] = 7;
    lut[_stateHrR1] = 7;
    for (var i = 1; i < 16; i++) {
      lut[_stateHlR1 | i] = 8;
      lut[_stateHrR1 | i] = 8;
    }
    for (var i = 1; i < 4; i++) {
      for (var j = 0; j < 16; j++) {
        lut[_stateHlR1 | (i << 4) | j] = 9;
        lut[_stateHrR1 | (i << 4) | j] = 9;
      }
    }
    for (var i = 0; i < 64; i++) {
      lut[_stateHlR1 | _stateHrR1 | i] = 10;
    }
    return lut;
  }

  static List<int> _buildZcLutHl() {
    final lut = List<int>.filled(1 << _zcLutBits, 0, growable: false);
    lut[0] = 2;
    for (var i = 1; i < 16; i++) {
      lut[i] = 4;
    }
    for (var i = 0; i < 4; i++) {
      lut[1 << i] = 3;
    }
    for (var i = 0; i < 16; i++) {
      lut[_stateHlR1 | i] = 5;
      lut[_stateHrR1 | i] = 5;
      lut[_stateHlR1 | _stateHrR1 | i] = 6;
    }
    lut[_stateVuR1] = 7;
    lut[_stateVdR1] = 7;
    for (var i = 1; i < 16; i++) {
      lut[_stateVuR1 | i] = 8;
      lut[_stateVdR1 | i] = 8;
    }
    for (var i = 1; i < 4; i++) {
      for (var j = 0; j < 16; j++) {
        lut[(i << 6) | _stateVuR1 | j] = 9;
        lut[(i << 6) | _stateVdR1 | j] = 9;
      }
    }
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 16; j++) {
        lut[(i << 6) | _stateVuR1 | _stateVdR1 | j] = 10;
      }
    }
    return lut;
  }

  static List<int> _buildZcLutHh() {
    final lut = List<int>.filled(1 << _zcLutBits, 0, growable: false);
    lut[0] = 2;
    final twoBits = <int>[3, 5, 6, 9, 10, 12];
    final oneBit = <int>[1, 2, 4, 8];
    final twoLeast = <int>[3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15];
    final threeLeast = <int>[7, 11, 13, 14, 15];

    for (final t in oneBit) {
      lut[t << 4] = 3;
    }
    for (final t in twoLeast) {
      lut[t << 4] = 4;
    }
    for (final t in oneBit) {
      lut[t] = 5;
    }
    for (final h in oneBit) {
      for (final d in oneBit) {
        lut[(h << 4) | d] = 6;
      }
    }
    for (final h in twoLeast) {
      for (final d in oneBit) {
        lut[(h << 4) | d] = 7;
      }
    }
    for (final d in twoBits) {
      lut[d] = 8;
    }
    for (var h = 0; h < 16; h++) {
      for (final d in twoBits) {
        lut[(h << 4) | d] = 9;
      }
    }
    for (var h = 0; h < 16; h++) {
      for (final d in threeLeast) {
        lut[(h << 4) | d] = 10;
      }
    }
    return lut;
  }

  static List<int> _buildScLut() {
    final lut = List<int>.filled(1 << _scLutBits, 0, growable: false);
    final inter = List<int>.filled(36, 0, growable: false);
    inter[(2 << 3) | 2] = 15;
    inter[(2 << 3) | 1] = 14;
    inter[(2 << 3) | 0] = 13;
    inter[(1 << 3) | 2] = 12;
    inter[(1 << 3) | 1] = 11;
    inter[(1 << 3) | 0] = 12 | _intSignBit;
    inter[(0 << 3) | 2] = 13 | _intSignBit;
    inter[(0 << 3) | 1] = 14 | _intSignBit;
    inter[(0 << 3) | 0] = 15 | _intSignBit;

    for (var i = 0; i < (1 << _scLutBits) - 1; i++) {
      final ds = i & 0x01;
      final us = (i >> 1) & 0x01;
      final rs = (i >> 2) & 0x01;
      final ls = (i >> 3) & 0x01;
      final dsgn = (i >> 5) & 0x01;
      final usgn = (i >> 6) & 0x01;
      final rsgn = (i >> 7) & 0x01;
      final lsgn = (i >> 8) & 0x01;
      var h = ls * (1 - 2 * lsgn) + rs * (1 - 2 * rsgn);
      h = h >= -1 ? h : -1;
      h = h <= 1 ? h : 1;
      var v = us * (1 - 2 * usgn) + ds * (1 - 2 * dsgn);
      v = v >= -1 ? v : -1;
      v = v <= 1 ? v : 1;
      lut[i] = inter[(h + 1) << 3 | (v + 1)];
    }
    return lut;
  }

  static List<int> _buildMrLut() {
    final lut = List<int>.filled(1 << _mrLutBits, 0, growable: false);
    lut[0] = 16;
    for (var i = 1; i < (1 << (_mrLutBits - 1)); i++) {
      lut[i] = 17;
    }
    for (var i = 1 << (_mrLutBits - 1); i < (1 << _mrLutBits); i++) {
      lut[i] = 18;
    }
    return lut;
  }
}

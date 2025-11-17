import 'dart:io';

import '../codestream/header_info.dart';
import '../codestream/reader/bitstream_reader_agent.dart';
import '../codestream/reader/header_decoder.dart';
import '../entropy/decoder/entropy_decoder.dart';
import '../entropy/decoder/std_entropy_decoder.dart';
import '../fileformat/file_format_reader.dart';
import '../io/be_buffered_random_access_file.dart';
import '../io/random_access_io.dart';
import '../quantization/dequantizer/std_dequantizer.dart';
import '../roi/roi_de_scaler.dart';
import '../util/facility_manager.dart';
import '../util/msg_logger.dart';
import '../util/parameter_list.dart';
import '../util/string_format_exception.dart';
import '../wavelet/synthesis/inverse_wt.dart';
import '../image/blk_img_data_src.dart';
import '../image/img_data_converter.dart';
import '../image/invcomptransf/inv_component_transformer.dart';
import '../image/invcomptransf/inv_comp_transf.dart';
import '../image/output/composite_img_writer.dart';
import '../image/output/img_writer.dart';
import '../image/output/img_writer_pgm.dart';
import '../image/output/img_writer_pgx.dart';
import '../image/output/img_writer_ppm.dart';
import 'decoder_specs.dart';

/// Minimal port of JJ2000's `Decoder` orchestration.
///
/// TODO The Dart version currently instantiates the core decoding stages up to
/// the inverse wavelet transform and sample conversion. Future work should wire
/// colour management, component transforms beyond reversible/irreversible
/// lifting, output image writers, and full tile decoding to produce raster
/// imagery.
class Decoder implements Runnable {
  Decoder(this.pl)
      : defpl = pl.getDefaultParameterList(),
        hi = HeaderInfo();

  /// The parameter list used to configure the decoder.
  final ParameterList pl;

  /// Default parameter list inherited from the caller.
  final ParameterList? defpl;

  /// Aggregated codestream metadata captured during header parsing.
  final HeaderInfo hi;

  /// Exit code produced by [run]; zero indicates success.
  int exitCode = 0;

  /// Decoder specifications populated from the main header.
  DecoderSpecs? decSpec;

  /// Header decoder responsible for parsing marker segments.
  HeaderDecoder? headerDecoder;

  /// Bit-stream reader responsible for delivering coded code-block data.
  BitstreamReaderAgent? bitstreamReader;

  /// Entropy decoder instantiated for the current codestream.
  StdEntropyDecoder? entropyDecoder;

  /// ROI de-scaler responsible for restoring background sample magnitude.
  ROIDeScaler? roiDeScaler;

  /// Dequantizer producing inverse-quantized coefficients.
  StdDequantizer? dequantizer;

  /// Inverse wavelet transform reconstructing spatial samples from coefficients.
  InverseWT? inverseWT;

  /// Component/sample type converter applied after the inverse wavelet stage.
  ImgDataConverter? imageDataConverter;

  /// Optional inverse component transform stage (ICT/RCT).
  InvCompTransfImgDataSrc? componentTransformer;

  /// Active codestream handle retained for downstream stages.
  RandomAccessIO? _codestream;

  /// Provides the current image data source after all instantiated stages.
  BlkImgDataSrc? get imageDataSource =>
      componentTransformer ?? imageDataConverter ?? inverseWT;

  /// Static option descriptors used by command-line front ends.
  static const List<List<String>> pinfo = <List<String>>[
    <String>['u', '[on|off]', 'Prints usage information.', 'off'],
    <String>['v', '[on|off]', 'Prints version information.', 'off'],
    <String>['verbose', '[on|off]', 'Emits codestream diagnostics.', 'on'],
    <String>['i', '<filename or url>', 'Input JPEG 2000 codestream/JP2.', ''],
    <String>['o', '<filename>', 'Output image filename.', ''],
    <String>['debug', '[on|off]', 'Print debugging stack traces.', 'off'],
  ];

  static const List<int> vprfxs =
      <int>[]; // Decoder-specific prefixes handled elsewhere.

  MsgLogger get _logger => FacilityManager.getMsgLogger();

  static List<List<String>> getParameterInfo() => pinfo;

  @override
  void run() {
    try {
      _runInternal();
    } on StringFormatException catch (error) {
      _error('Invalid arguments: ${error.message}', 1, error);
    } on IOException catch (error) {
      _error('I/O error: $error', 2, error);
    } on Exception catch (error) {
      _error('Unexpected error: $error', 3, error);
    }
  }

  void _runInternal() {
    pl.checkList(vprfxs, ParameterList.toNameArray(pinfo));

    if (pl.getParameter('u') == 'on') {
      _printUsage();
      exitCode = 0;
      return;
    }

    if (pl.getParameter('v') == 'on') {
      _printVersion();
    }

    final inputPath = pl.getParameter('i');
    if (inputPath == null || inputPath.isEmpty) {
      throw StateError("Input file ('-i') has not been specified");
    }

    final file = _openInput(inputPath);

    try {
      final ff = FileFormatReader(file);
      ff.readFileFormat();
      final codestreamOffset = ff.JP2FFUsed ? ff.getFirstCodeStreamPos() : 0;
      if (codestreamOffset > 0) {
        file.seek(codestreamOffset);
      }

      _logger.printmsg(MsgLogger.info,
          'JP2 wrapper: ${ff.JP2FFUsed ? 'present' : 'absent'}');

      headerDecoder = HeaderDecoder.readMainHeader(
        input: file,
        headerInfo: hi,
      );
      final decoder = headerDecoder!;
      decSpec = decoder.decSpec;

      _logger.printmsg(
        MsgLogger.info,
        'Parsed codestream main header: ${decoder.getNumComps()} component(s), '
        '${decoder.getImgWidth()}x${decoder.getImgHeight()} image.',
      );

      var tilePartCount = 0;
      final tilePartPerTile = <int, int>{};

      while (true) {
        final start = file.getPos();
        try {
          final sot = decoder.parseNextTilePart(file);
          tilePartCount++;
          tilePartPerTile[sot.isot] = (tilePartPerTile[sot.isot] ?? 0) + 1;

          final psot = sot.psot;
          if (psot == 0) {
            _logger.printmsg(
              MsgLogger.warning,
              'Tile-part length unknown (Psot=0) for tile=${sot.isot} part=${sot.tpsot}; '
              'stopping tile scan after headers.',
            );
            break;
          }

          final expectedEnd = start + psot;
          if (expectedEnd < file.getPos()) {
            _logger.printmsg(
              MsgLogger.warning,
              'Tile-part length shorter than parsed header for tile=${sot.isot} part=${sot.tpsot}; '
              'aborting tile scan.',
            );
            break;
          }
          if (expectedEnd > file.length()) {
            _logger.printmsg(
              MsgLogger.warning,
              'Tile-part length exceeds codestream bounds for tile=${sot.isot} part=${sot.tpsot}; '
              'stopping at end of stream.',
            );
            file.seek(file.length());
            break;
          }

          file.seek(expectedEnd);
        } on StateError catch (error) {
          final message = error.message;
          if (message.contains(
              'Reached end of codestream before encountering tile-part header')) {
            break;
          }
          rethrow;
        }
      }

      if (tilePartCount == 0) {
        _logger.printmsg(MsgLogger.info, 'No tile-part headers encountered.');
      } else {
        final summaries = tilePartPerTile.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final entry in summaries) {
          _logger.printmsg(
            MsgLogger.info,
            'Tile ${entry.key} has ${entry.value} tile-part header(s).',
          );
        }
        _logger.printmsg(
            MsgLogger.info, 'Parsed $tilePartCount tile-part header(s).');
      }

      _initialiseCodestreamPipeline(file, decoder);
      _executeOutputStage();
    } finally {
      if (_codestream != null) {
        dispose();
      } else {
        file.close();
      }
    }
  }

  RandomAccessIO _openInput(String pathOrUrl) {
    // Networking support is deferred; the current implementation only accepts
    // file system paths.
    final file = File(pathOrUrl);
    if (!file.existsSync()) {
      throw FileSystemException('Input file not found', pathOrUrl);
    }
    return BEBufferedRandomAccessFile.path(pathOrUrl, 'r');
  }

  void _initialiseCodestreamPipeline(
      RandomAccessIO input, HeaderDecoder decoder) {
    if (decSpec == null) {
      throw StateError(
          'Decoder specifications unavailable when initialising codestream pipeline');
    }

    _codestream = input;
    final bitstreamParams =
        _subsetParametersByPrefix(pl, BitstreamReaderAgent.optPrefix);
    final emitCodestreamInfo = _getBooleanOption(pl, 'cdstr_info', false);
    bitstreamReader = BitstreamReaderAgent.createInstance(
      input,
      decoder,
      bitstreamParams,
      decSpec!,
      emitCodestreamInfo,
      hi,
    );

    final entropyParams =
        _subsetParametersByPrefix(pl, EntropyDecoder.optionPrefix);
    entropyDecoder =
        decoder.createEntropyDecoder(bitstreamReader!, entropyParams);
    _logger.printmsg(
      MsgLogger.info,
      'Instantiated entropy decoder for ${decoder.getNumComps()} component(s).',
    );

    final roiParams = _subsetParametersByPrefix(pl, ROIDeScaler.optionPrefix);
    roiDeScaler = decoder.createROIDeScaler(entropyDecoder!, roiParams);
    _logger.printmsg(
      MsgLogger.info,
      'Instantiated ROI de-scaler wrapper.',
    );

    final rangeBits = List<int>.generate(
      decoder.getNumComps(),
      decoder.getOriginalBitDepth,
      growable: false,
    );
    dequantizer = decoder.createDequantizer(roiDeScaler!, rangeBits);
    _logger.printmsg(
      MsgLogger.info,
      'Instantiated dequantizer using StdDequantizer.',
    );

    inverseWT = InverseWT.createInstance(dequantizer!, decSpec!);
    _logger.printmsg(
      MsgLogger.info,
      'Instantiated inverse wavelet transform.',
    );

    final targetResolution = bitstreamReader?.getImgRes() ?? 0;
    inverseWT!.setImgResLevel(targetResolution);
    _logger.printmsg(
      MsgLogger.info,
      'Configured inverse wavelet transform for resolution level $targetResolution.',
    );

    final initialFixedPoint = inverseWT!.getFixedPoint(0);
    imageDataConverter = ImgDataConverter(inverseWT!, initialFixedPoint);
    _logger.printmsg(
      MsgLogger.info,
      'Instantiated image data converter (fixed-point=$initialFixedPoint).',
    );

    if (decSpec!.cts.isCompTransfUsed()) {
      componentTransformer = InvCompTransfImgDataSrc(
        imageDataConverter!,
        decSpec!.cts,
      );
        final transform = decSpec!.cts.getSpec(0, 0) ?? InvCompTransf.none;
      final label = transform == InvCompTransf.invRct
          ? 'RCT'
          : (transform == InvCompTransf.invIct ? 'ICT' : 'custom');
      _logger.printmsg(
        MsgLogger.info,
        'Instantiated inverse component transform ($label).',
      );
    }
  }

  void _executeOutputStage() {
    final outputPath = pl.getParameter('o');
    if (outputPath == null || outputPath.isEmpty) {
      _logger.printmsg(
        MsgLogger.info,
        'No output filename specified; skipping raster export.',
      );
      return;
    }

    final writer = _createWriter(outputPath);
    try {
      _logger.printmsg(
        MsgLogger.info,
        'Writing decoded image to $outputPath (${writer.runtimeType}).',
      );
      writer.writeAll();
      writer.flush();
      _logger.printmsg(
        MsgLogger.info,
        'Completed writing $outputPath.',
      );
    } finally {
      writer.close();
    }
  }

  ImgWriter _createWriter(String outputPath) {
    final source = imageDataSource;
    if (source == null) {
      throw StateError('Image data source not initialised; cannot write output.');
    }

    final lower = outputPath.toLowerCase();
    if (lower.endsWith('.ppm')) {
      const requiredComponents = 3;
      if (source.getNumComps() < requiredComponents) {
        throw StateError(
          'PPM output expects at least $requiredComponents components; '
          'decoder produced ${source.getNumComps()}.',
        );
      }
      for (var c = 0; c < requiredComponents; c++) {
        final rangeBits = source.getNomRangeBits(c);
        if (rangeBits > 8) {
          throw StateError(
            'Component $c has $rangeBits-bit samples; PPM writer only supports up to 8 bits.',
          );
        }
      }
      return ImgWriterPpm.fromPath(outputPath, source, 0, 1, 2);
    }

    if (lower.endsWith('.pgm')) {
      if (source.getNumComps() == 0) {
        throw StateError('Decoded image has no components to export.');
      }
      // For multi-component codestreams we match JJ2000 behaviour: emit one
      // file per component with a numeric suffix.
      if (source.getNumComps() == 1) {
        return ImgWriterPgm.fromPath(outputPath, source, 0);
      }
      final writers = <ImgWriter>[];
      for (var c = 0; c < source.getNumComps(); c++) {
        writers.add(
          ImgWriterPgm.fromPath(
            _componentPath(outputPath, c),
            source,
            c,
          ),
        );
      }
      return CompositeImgWriter(writers);
    }

    if (lower.endsWith('.pgx')) {
      if (source.getNumComps() == 0) {
        throw StateError('Decoded image has no components to export.');
      }
      if (source.getNumComps() == 1) {
        return ImgWriterPgx.fromPath(
          outputPath,
          source,
          0,
          _isComponentSigned(source, 0),
        );
      }
      final writers = <ImgWriter>[];
      for (var c = 0; c < source.getNumComps(); c++) {
        writers.add(
          ImgWriterPgx.fromPath(
            _componentPath(outputPath, c),
            source,
            c,
            _isComponentSigned(source, c),
          ),
        );
      }
      return CompositeImgWriter(writers);
    }

    throw UnsupportedError(
      'Output format for "$outputPath" is not supported yet. Only .ppm exports are implemented.',
    );
  }

  String _componentPath(String basePath, int componentIndex) {
    final dot = basePath.lastIndexOf('.');
    if (dot <= 0) {
      return '${basePath}_c${componentIndex + 1}';
    }
    final stem = basePath.substring(0, dot);
    final ext = basePath.substring(dot);
    return '$stem-${componentIndex + 1}$ext';
  }

  bool _isComponentSigned(BlkImgDataSrc source, int component) {
    if (componentTransformer != null) {
      // Component transforms produce unsigned output for ICT/RCT scenarios.
      return false;
    }
    if (headerDecoder == null) {
      return false;
    }
    return headerDecoder!.isOriginalSigned(component);
  }
  ParameterList _subsetParametersByPrefix(ParameterList source, String prefix) {
    ParameterList? filteredDefaults;
    final defaults = source.getDefaultParameterList();
    if (defaults != null) {
      final candidate = _subsetParametersByPrefix(defaults, prefix);
      if (!_parameterListIsEmpty(candidate)) {
        filteredDefaults = candidate;
      }
    }

    final subset = ParameterList(filteredDefaults);
    if (prefix.isEmpty) {
      return subset;
    }

    final prefixCode = prefix.codeUnitAt(0);
    for (final name in source.propertyNames()) {
      if (name.isEmpty || name.codeUnitAt(0) != prefixCode) {
        continue;
      }
      final value = source.getParameter(name);
      if (value != null) {
        subset.put(name, value);
      }
    }
    return subset;
  }

  bool _parameterListIsEmpty(ParameterList list) {
    for (final _ in list.propertyNames()) {
      return false;
    }
    return true;
  }

  bool _getBooleanOption(ParameterList list, String name, bool fallback) {
    final raw = list.getParameter(name);
    if (raw == null) {
      return fallback;
    }
    if (raw == 'on') {
      return true;
    }
    if (raw == 'off') {
      return false;
    }
    throw StringFormatException('Parameter "$name" is not boolean: $raw');
  }

  /// Releases the codestream resources attached to this decoder.
  void dispose() {
    try {
      _codestream?.close();
    } finally {
      _codestream = null;
    }
  }

  void _printUsage() {
    final buffer = StringBuffer('JPEG 2000 decoder options:\n');
    for (final option in pinfo) {
      buffer.writeln(
          ' -${option[0]} : ${option[1]}\n    ${option[2]} (default: ${option[3]})');
    }
    _logger.println(buffer.toString(), 0, 2);
  }

  void _printVersion() {
    _logger.printmsg(
        MsgLogger.info, 'JJ2000 Decoder (Dart port) - preview build');
  }

  void _error(String message, int code, Object? error) {
    exitCode = code;
    _logger.printmsg(MsgLogger.error, message);
    if (pl.getParameter('debug') == 'on' && error is Error) {
      _logger.printmsg(MsgLogger.error, error.stackTrace.toString());
    }
  }
}

/// Matches java.lang.Runnable so the decoder can be scheduled by utilities.
abstract class Runnable {
  void run();
}

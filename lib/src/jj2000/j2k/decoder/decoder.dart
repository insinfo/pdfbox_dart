import 'dart:io';

import '../codestream/header_info.dart';
import '../codestream/reader/header_decoder.dart';
import '../fileformat/file_format_reader.dart';
import '../io/be_buffered_random_access_file.dart';
import '../io/random_access_io.dart';
import '../util/facility_manager.dart';
import '../util/msg_logger.dart';
import '../util/parameter_list.dart';
import '../util/string_format_exception.dart';
import 'decoder_specs.dart';

/// Minimal port of JJ2000's `Decoder` orchestration.
///
/// TODO The Dart version currently stops after validating the codestream wrapper
/// and instantiating the placeholder [HeaderDecoder]. Future work should wire
/// the remaining decoding stages (bit-stream reader, entropy, dequantisation,
/// inverse wavelet transform, colour management and image writers).
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

  /// Static option descriptors used by command-line front ends.
  static const List<List<String>> pinfo = <List<String>>[
    <String>['u', '[on|off]', 'Prints usage information.', 'off'],
    <String>['v', '[on|off]', 'Prints version information.', 'off'],
    <String>['verbose', '[on|off]', 'Emits codestream diagnostics.', 'on'],
    <String>['i', '<filename or url>', 'Input JPEG 2000 codestream/JP2.', ''],
    <String>['o', '<filename>', 'Output image filename.', ''],
    <String>['debug', '[on|off]', 'Print debugging stack traces.', 'off'],
  ];

  static const List<int> vprfxs = <int>[]; // Decoder-specific prefixes handled elsewhere.

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

      _logger.printmsg(MsgLogger.info, 'JP2 wrapper: ${ff.JP2FFUsed ? 'present' : 'absent'}');

      headerDecoder = HeaderDecoder.readMainHeader(
        input: file,
        headerInfo: hi,
      );
      decSpec = headerDecoder!.decSpec;

      _logger.printmsg(
        MsgLogger.info,
        'Parsed codestream main header: ${headerDecoder!.getNumComps()} component(s), '
        '${headerDecoder!.getImgWidth()}x${headerDecoder!.getImgHeight()} image.',
      );
    } finally {
      file.close();
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

  void _printUsage() {
    final buffer = StringBuffer('JPEG 2000 decoder options:\n');
    for (final option in pinfo) {
      buffer.writeln(' -${option[0]} : ${option[1]}\n    ${option[2]} (default: ${option[3]})');
    }
    _logger.println(buffer.toString(), 0, 2);
  }

  void _printVersion() {
    _logger.printmsg(MsgLogger.info, 'JJ2000 Decoder (Dart port) - preview build');
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

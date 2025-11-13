import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../io/exceptions.dart';
import '../../io/random_access_read_buffer.dart';
import '../contentstream/operator/operator.dart';
import '../contentstream/operator/operator_name.dart';
import '../contentstream/pd_content_stream.dart';
import '../cos/cos_base.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_float.dart';
import '../cos/cos_integer.dart';
import '../cos/cos_name.dart';
import '../cos/cos_null.dart';
import '../cos/cos_string.dart';
import 'base_parser.dart';
import 'cos_parser.dart';

/// Parser for PDF content streams mirroring PDFBox's PDFStreamParser.
class PDFStreamParser extends COSParser {
  PDFStreamParser(PDContentStream contentStream)
      : _logger = Logger('pdfbox.PDFStreamParser'),
        super(contentStream.getContentsForStreamParsing());

  PDFStreamParser.fromBytes(List<int> bytes)
      : _logger = Logger('pdfbox.PDFStreamParser'),
        super(RandomAccessReadBuffer.fromBytes(Uint8List.fromList(bytes)));

  static const int _maxBinCharTestLength = 10;

  final Logger _logger;
  final Uint8List _binCharTestArr = Uint8List(_maxBinCharTestLength);
  int _inlineImageDepth = 0;
  int _inlineOffset = 0;

  /// Parses the complete stream and returns all tokens.
  List<Object?> parse() {
    final streamObjects = <Object?>[];
    Object? token;
    while ((token = parseNextToken()) != null) {
      streamObjects.add(token);
    }
    return streamObjects;
  }

  /// Parses the next token in the stream or returns null when EOF is reached.
  Object? parseNextToken() {
    if (source.isClosed) {
      return null;
    }
    skipSpaces();
    if (source.isEOF) {
      close();
      return null;
    }

    final peeked = source.peek();
    if (peeked == -1) {
      close();
      return null;
    }
    final c = peeked;

    switch (c) {
      case 0x3c: // '<'
        source.read();
        final next = source.peek();
        if (next == 0x3c) {
          source.rewind(1);
          try {
            return parseCOSDictionary(true);
          } on IOException catch (exception) {
            _logger.warning(
                'Stop reading invalid dictionary from content stream at offset ${source.position}: $exception');
            close();
            return null;
          }
        }
        return parseCOSHexString();
      case 0x5b: // '['
        try {
          return parseCOSArray();
        } on IOException catch (exception) {
          _logger.warning(
              'Stop reading invalid array from content stream at offset ${source.position}: $exception');
          close();
          return null;
        }
      case 0x28: // '('
        return COSString.fromBytes(readLiteralString());
      case 0x2f: // '/'
        return parseCOSName();
      case 0x6e: // 'n'
        final nullString = readString();
        if (nullString == 'null') {
          return COSNull.instance;
        }
        return Operator.getOperator(nullString);
      case 0x74: // 't'
      case 0x66: // 'f'
        final next = readString();
        if (next == 'true') {
          return COSBoolean.trueValue;
        }
        if (next == 'false') {
          return COSBoolean.falseValue;
        }
        return Operator.getOperator(next);
      case 0x30: // '0'
      case 0x31: // '1'
      case 0x32: // '2'
      case 0x33: // '3'
      case 0x34: // '4'
      case 0x35: // '5'
      case 0x36: // '6'
      case 0x37: // '7'
      case 0x38: // '8'
      case 0x39: // '9'
      case 0x2d: // '-'
      case 0x2b: // '+'
      case 0x2e: // '.'
        return _parseNumberToken(c);
      case 0x42: // 'B'
        final nextOperator = readString();
        final beginImageOp = Operator.getOperator(nextOperator);
        if (nextOperator == OperatorName.beginInlineImage) {
          _inlineImageDepth++;
          if (_inlineImageDepth > 1) {
            throw IOException(
                "Nested '${OperatorName.beginInlineImage}' operator not allowed at offset ${source.position}, first: $_inlineOffset");
          }
          _inlineOffset = source.position;
          final imageParams = COSDictionary();
          beginImageOp.setImageParameters(imageParams);
          while (true) {
            final nextToken = parseNextToken();
            if (nextToken is COSName) {
              final value = parseNextToken();
              if (value is! COSBase) {
                final offset = source.isClosed ? 'EOF' : '${source.position}';
                _logger.warning(
                    'Unexpected token in inline image dictionary at offset $offset');
                break;
              }
              imageParams.setItem(nextToken, value);
              continue;
            }
            if (nextToken is Operator) {
              if (nextToken.imageData == null || nextToken.imageData!.isEmpty) {
                final offset = source.isClosed ? 'EOF' : '${source.position}';
                _logger.warning('Empty inline image at stream offset $offset');
              }
              beginImageOp.setImageData(nextToken.imageData);
              _inlineImageDepth--;
            } else {
              final offset = source.isClosed ? 'EOF' : '${source.position}';
              _logger.warning(
                  'nextToken $nextToken at position $offset, expected ${OperatorName.beginInlineImageData}');
            }
            break;
          }
        }
        return beginImageOp;
      case 0x49: // 'I'
        final first = source.read();
        final second = source.read();
        final id = String.fromCharCode(first) + String.fromCharCode(second);
        if (id != OperatorName.beginInlineImageData) {
          final currentPosition = source.position;
          close();
          throw IOException(
              "Error: Expected operator 'ID' actual='$id' at stream offset $currentPosition");
        }
        final imageData = BytesBuilder(copy: false);
        if (!skipLinebreak() && isWhitespace()) {
          source.read();
        }
        var lastByte = source.read();
        var currentByte = source.read();
        while (lastByte != -1 && currentByte != -1) {
          final isEI = lastByte == 0x45 &&
              currentByte == 0x49 &&
              _hasNextSpaceOrReturn() &&
              _hasNoFollowingBinData();
          if (isEI || source.isEOF) {
            break;
          }
          imageData.addByte(lastByte);
          lastByte = currentByte;
          currentByte = source.read();
        }
        final beginImageDataOp =
            Operator.getOperator(OperatorName.beginInlineImageData);
        beginImageDataOp.setImageData(imageData.takeBytes());
        return beginImageDataOp;
      case 0x5d: // ']'
        source.read();
        return COSNull.instance;
      default:
        final operator = _readOperator().trim();
        if (operator.isNotEmpty) {
          return Operator.getOperator(operator);
        }
    }
    return null;
  }

  COSBase _parseNumberToken(int initialChar) {
    final buffer = StringBuffer();
    buffer.writeCharCode(initialChar);
    source.read();
    if (initialChar == 0x2d && source.peek() == 0x2d) {
      source.read();
    }

    var dotNotRead = initialChar != 0x2e;
    while (true) {
      final next = source.peek();
      if (next == -1) {
        break;
      }
      final isDigit = BaseParser.isDigit(next);
      final isDot = dotNotRead && next == 0x2e;
      final isMinus = next == 0x2d;
      if (!isDigit && !isDot && !isMinus) {
        break;
      }
      source.read();
      if (!isMinus) {
        buffer.writeCharCode(next);
      }
      if (isDot) {
        dotNotRead = false;
      }
    }

    final token = buffer.toString();
    if (token == '+') {
      _logger.warning("isolated '+' is ignored");
      return COSNull.instance;
    }
    return _tokenToCosNumber(token);
  }

  COSBase _tokenToCosNumber(String token) {
    if (token.contains('.') || token.contains('e') || token.contains('E')) {
      final value = double.tryParse(token);
      if (value == null) {
        throw IOException("Error: Expected a float value, got '$token'");
      }
      return COSFloat.valueOf(value);
    }
    final value = int.tryParse(token);
    if (value == null) {
      throw IOException("Error: Expected an integer value, got '$token'");
    }
    return COSInteger.valueOf(value);
  }

  bool _hasNoFollowingBinData() {
    final readBytes =
        source.readBuffer(_binCharTestArr, 0, _maxBinCharTestLength);
    var noBinData = true;
    var startOpIdx = -1;
    var endOpIdx = -1;
    var s = '';

    if (readBytes > 0) {
      for (var bIdx = 0; bIdx < readBytes; bIdx++) {
        final byte = _binCharTestArr[bIdx];
        if ((byte != 0 && byte < 0x09) ||
            (byte > 0x0a && byte < 0x20 && byte != 0x0d)) {
          noBinData = false;
          break;
        }
        if (startOpIdx == -1 &&
            byte != 0 &&
            byte != 9 &&
            byte != 0x20 &&
            byte != 0x0a &&
            byte != 0x0d) {
          startOpIdx = bIdx;
        } else if (startOpIdx != -1 &&
            endOpIdx == -1 &&
            (byte == 0 ||
                byte == 9 ||
                byte == 0x20 ||
                byte == 0x0a ||
                byte == 0x0d)) {
          endOpIdx = bIdx;
        }
      }

      if (noBinData && endOpIdx != -1 && startOpIdx != -1) {
        s = String.fromCharCodes(_binCharTestArr.sublist(startOpIdx, endOpIdx));
        if (s != 'Q' && s != 'EMC' && s != 'S' && !_numberRegex.hasMatch(s)) {
          noBinData = false;
        }
      }

      if (noBinData && startOpIdx != -1 && readBytes == _maxBinCharTestLength) {
        if (endOpIdx == -1) {
          endOpIdx = _maxBinCharTestLength;
          s = String.fromCharCodes(
              _binCharTestArr.sublist(startOpIdx, endOpIdx));
        }
        if (endOpIdx - startOpIdx > 3 && !_numberRegex.hasMatch(s)) {
          noBinData = false;
        }
      }
      source.rewind(readBytes);
    }

    if (!noBinData) {
      _logger.warning(
          "ignoring 'EI' assumed to be in the middle of inline image at stream offset ${source.position}, s = '$s'");
    }
    return noBinData;
  }

  static final RegExp _numberRegex = RegExp(r'^\d*\.?\d*$');

  String _readOperator() {
    skipSpaces();
    final buffer = StringBuffer();
    var nextChar = source.peek();
    while (nextChar != -1 &&
        !BaseParser.isWhitespace(nextChar) &&
        nextChar != 0x5b && // '['
        nextChar != 0x3c && // '<'
        nextChar != 0x28 && // '('
        nextChar != 0x2f && // '/'
        nextChar != 0x25 && // '%'
        (nextChar < 0x30 || nextChar > 0x39)) {
      final currentChar = source.read();
      buffer.writeCharCode(currentChar);
      nextChar = source.peek();
      if (currentChar == 0x64 && (nextChar == 0x30 || nextChar == 0x31)) {
        buffer.writeCharCode(source.read());
        nextChar = source.peek();
      }
    }
    return buffer.toString();
  }

  bool _hasNextSpaceOrReturn() {
    return _isSpaceOrReturn(source.peek());
  }

  bool _isSpaceOrReturn(int c) {
    return c == 0x0a || c == 0x0d || c == 0x20;
  }

  void close() {
    if (!source.isClosed) {
      source.close();
    }
  }
}

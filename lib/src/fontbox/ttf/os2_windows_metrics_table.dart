import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'package:pdfbox_dart/src/io/exceptions.dart';

import '../io/ttf_data_stream.dart';
import 'ttf_table.dart';

/// TrueType OS/2 and Windows metrics table.
class Os2WindowsMetricsTable extends TtfTable {
  static const String tableTag = 'OS/2';

  static final Logger _log = Logger('fontbox.Os2WindowsMetricsTable');

  // Weight class constants.
  static const int weightClassThin = 100;
  static const int weightClassUltraLight = 200;
  static const int weightClassLight = 300;
  static const int weightClassNormal = 400;
  static const int weightClassMedium = 500;
  static const int weightClassSemiBold = 600;
  static const int weightClassBold = 700;
  static const int weightClassExtraBold = 800;
  static const int weightClassBlack = 900;

  // Width class constants.
  static const int widthClassUltraCondensed = 1;
  static const int widthClassExtraCondensed = 2;
  static const int widthClassCondensed = 3;
  static const int widthClassSemiCondensed = 4;
  static const int widthClassMedium = 5;
  static const int widthClassSemiExpanded = 6;
  static const int widthClassExpanded = 7;
  static const int widthClassExtraExpanded = 8;
  static const int widthClassUltraExpanded = 9;

  // Family class constants.
  static const int familyClassNoClassification = 0;
  static const int familyClassOldstyleSerifs = 1;
  static const int familyClassTransitionalSerifs = 2;
  static const int familyClassModernSerifs = 3;
  static const int familyClassClaredonSerifs = 4;
  static const int familyClassSlabSerifs = 5;
  static const int familyClassFreeformSerifs = 7;
  static const int familyClassSansSerif = 8;
  static const int familyClassOrnamentals = 9;
  static const int familyClassScripts = 10;
  static const int familyClassSymbolic = 12;

  // Embedding flags.
  static const int fsTypeRestricted = 0x0002;
  static const int fsTypePreviewAndPrint = 0x0004;
  static const int fsTypeEditable = 0x0008;
  static const int fsTypeNoSubsetting = 0x0100;
  static const int fsTypeBitmapOnly = 0x0200;

  int _version = 0;
  int _averageCharWidth = 0;
  int _weightClass = 0;
  int _widthClass = 0;
  int _fsType = 0;
  int _subscriptXSize = 0;
  int _subscriptYSize = 0;
  int _subscriptXOffset = 0;
  int _subscriptYOffset = 0;
  int _superscriptXSize = 0;
  int _superscriptYSize = 0;
  int _superscriptXOffset = 0;
  int _superscriptYOffset = 0;
  int _strikeoutSize = 0;
  int _strikeoutPosition = 0;
  int _familyClass = 0;
  Uint8List _panose = Uint8List(10);
  int _unicodeRange1 = 0;
  int _unicodeRange2 = 0;
  int _unicodeRange3 = 0;
  int _unicodeRange4 = 0;
  String _achVendId = 'XXXX';
  int _fsSelection = 0;
  int _firstCharIndex = 0;
  int _lastCharIndex = 0;
  int _typoAscender = 0;
  int _typoDescender = 0;
  int _typoLineGap = 0;
  int _winAscent = 0;
  int _winDescent = 0;
  int _codePageRange1 = 0;
  int _codePageRange2 = 0;
  int _sxHeight = 0;
  int _sCapHeight = 0;
  int _usDefaultChar = 0;
  int _usBreakChar = 0;
  int _usMaxContext = 0;

  @override
  void read(dynamic ttf, TtfDataStream data) {
    try {
      _version = data.readUnsignedShort();
      _averageCharWidth = data.readSignedShort();
      _weightClass = data.readUnsignedShort();
      _widthClass = data.readUnsignedShort();
      _fsType = data.readSignedShort();
      _subscriptXSize = data.readSignedShort();
      _subscriptYSize = data.readSignedShort();
      _subscriptXOffset = data.readSignedShort();
      _subscriptYOffset = data.readSignedShort();
      _superscriptXSize = data.readSignedShort();
      _superscriptYSize = data.readSignedShort();
      _superscriptXOffset = data.readSignedShort();
      _superscriptYOffset = data.readSignedShort();
      _strikeoutSize = data.readSignedShort();
      _strikeoutPosition = data.readSignedShort();
      _familyClass = data.readSignedShort();
      _panose = Uint8List.fromList(data.readBytes(10));
      _unicodeRange1 = data.readUnsignedInt();
      _unicodeRange2 = data.readUnsignedInt();
      _unicodeRange3 = data.readUnsignedInt();
      _unicodeRange4 = data.readUnsignedInt();
      _achVendId = data.readString(4);
      _fsSelection = data.readUnsignedShort();
      _firstCharIndex = data.readUnsignedShort();
      _lastCharIndex = data.readUnsignedShort();
      _typoAscender = data.readSignedShort();
      _typoDescender = data.readSignedShort();
      _typoLineGap = data.readSignedShort();
      _winAscent = data.readUnsignedShort();
      _winDescent = data.readUnsignedShort();
    } on IOException {
      _log.fine('EOF encountered while reading legacy OS/2 table');
      setInitialized(true);
      return;
    }

    if (_version >= 1) {
      try {
        _codePageRange1 = data.readUnsignedInt();
        _codePageRange2 = data.readUnsignedInt();
      } on IOException catch (e) {
        _log.warning(
          'Could not read expected v1 OS/2 fields, downgrading version to 0',
          e,
        );
        _version = 0;
        _codePageRange1 = 0;
        _codePageRange2 = 0;
        setInitialized(true);
        return;
      }
    }

    if (_version >= 2) {
      try {
        _sxHeight = data.readSignedShort();
        _sCapHeight = data.readSignedShort();
        _usDefaultChar = data.readUnsignedShort();
        _usBreakChar = data.readUnsignedShort();
        _usMaxContext = data.readUnsignedShort();
      } on IOException catch (e) {
        _log.warning(
          'Could not read expected v2 OS/2 fields, downgrading version to 1',
          e,
        );
        _version = 1;
        _sxHeight = 0;
        _sCapHeight = 0;
        _usDefaultChar = 0;
        _usBreakChar = 0;
        _usMaxContext = 0;
        setInitialized(true);
        return;
      }
    }

    setInitialized(true);
  }

  int get version => _version;
  int get averageCharWidth => _averageCharWidth;
  int get weightClass => _weightClass;
  int get widthClass => _widthClass;
  int get fsType => _fsType;
  int get subscriptXSize => _subscriptXSize;
  int get subscriptYSize => _subscriptYSize;
  int get subscriptXOffset => _subscriptXOffset;
  int get subscriptYOffset => _subscriptYOffset;
  int get superscriptXSize => _superscriptXSize;
  int get superscriptYSize => _superscriptYSize;
  int get superscriptXOffset => _superscriptXOffset;
  int get superscriptYOffset => _superscriptYOffset;
  int get strikeoutSize => _strikeoutSize;
  int get strikeoutPosition => _strikeoutPosition;
  int get familyClass => _familyClass;
  Uint8List get panose => Uint8List.fromList(_panose);
  int get unicodeRange1 => _unicodeRange1;
  int get unicodeRange2 => _unicodeRange2;
  int get unicodeRange3 => _unicodeRange3;
  int get unicodeRange4 => _unicodeRange4;
  String get achVendId => _achVendId;
  int get fsSelection => _fsSelection;
  int get firstCharIndex => _firstCharIndex;
  int get lastCharIndex => _lastCharIndex;
  int get typoAscender => _typoAscender;
  int get typoDescender => _typoDescender;
  int get typoLineGap => _typoLineGap;
  int get winAscent => _winAscent;
  int get winDescent => _winDescent;
  int get codePageRange1 => _codePageRange1;
  int get codePageRange2 => _codePageRange2;
  int get height => _sxHeight;
  int get capHeight => _sCapHeight;
  int get defaultChar => _usDefaultChar;
  int get breakChar => _usBreakChar;
  int get maxContext => _usMaxContext;
}

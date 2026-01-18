import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../common/pd_rectangle.dart';
import '../../graphics/color/pd_gamma.dart';
import 'pd_standard_attribute_object.dart';
import 'pdf_four_colours.dart';

class PDLayoutAttributeObject extends PDStandardAttributeObject {
  static const String ownerLayout = 'Layout';

  static const String _placement = 'Placement';
  static const String _writingMode = 'WritingMode';
  static const String _backgroundColor = 'BackgroundColor';
  static const String _borderColor = 'BorderColor';
  static const String _borderStyle = 'BorderStyle';
  static const String _borderThickness = 'BorderThickness';
  static const String _padding = 'Padding';
  static const String _color = 'Color';
  static const String _spaceBefore = 'SpaceBefore';
  static const String _spaceAfter = 'SpaceAfter';
  static const String _startIndent = 'StartIndent';
  static const String _endIndent = 'EndIndent';
  static const String _textIndent = 'TextIndent';
  static const String _textAlign = 'TextAlign';
  static const String _bbox = 'BBox';
  static const String _width = 'Width';
  static const String _height = 'Height';
  static const String _blockAlign = 'BlockAlign';
  static const String _inlineAlign = 'InlineAlign';
  static const String _tBorderStyle = 'TBorderStyle';
  static const String _tPadding = 'TPadding';
  static const String _baselineShift = 'BaselineShift';
  static const String _lineHeight = 'LineHeight';
  static const String _textDecorationColor = 'TextDecorationColor';
  static const String _textDecorationThickness = 'TextDecorationThickness';
  static const String _textDecorationType = 'TextDecorationType';
  static const String _rubyAlign = 'RubyAlign';
  static const String _rubyPosition = 'RubyPosition';
  static const String _glyphOrientationVertical = 'GlyphOrientationVertical';
  static const String _columnCount = 'ColumnCount';
  static const String _columnGap = 'ColumnGap';
  static const String _columnWidths = 'ColumnWidths';

  static const String placementBlock = 'Block';
  static const String placementInline = 'Inline';
  static const String placementBefore = 'Before';
  static const String placementStart = 'Start';
  static const String placementEnd = 'End';

  static const String writingModeLrTb = 'LrTb';
  static const String writingModeRlTb = 'RlTb';
  static const String writingModeTbRl = 'TbRl';

  static const String borderStyleNone = 'None';
  static const String borderStyleHidden = 'Hidden';
  static const String borderStyleDotted = 'Dotted';
  static const String borderStyleDashed = 'Dashed';
  static const String borderStyleSolid = 'Solid';
  static const String borderStyleDouble = 'Double';
  static const String borderStyleGroove = 'Groove';
  static const String borderStyleRidge = 'Ridge';
  static const String borderStyleInset = 'Inset';
  static const String borderStyleOutset = 'Outset';

  static const String textAlignStart = 'Start';
  static const String textAlignCenter = 'Center';
  static const String textAlignEnd = 'End';
  static const String textAlignJustify = 'Justify';

  static const String widthAuto = 'Auto';
  static const String heightAuto = 'Auto';

  static const String blockAlignBefore = 'Before';
  static const String blockAlignMiddle = 'Middle';
  static const String blockAlignAfter = 'After';
  static const String blockAlignJustify = 'Justify';

  static const String inlineAlignStart = 'Start';
  static const String inlineAlignCenter = 'Center';
  static const String inlineAlignEnd = 'End';

  static const String lineHeightNormal = 'Normal';
  static const String lineHeightAuto = 'Auto';

  static const String textDecorationTypeNone = 'None';
  static const String textDecorationTypeUnderline = 'Underline';
  static const String textDecorationTypeOverline = 'Overline';
  static const String textDecorationTypeLineThrough = 'LineThrough';

  static const String rubyAlignStart = 'Start';
  static const String rubyAlignCenter = 'Center';
  static const String rubyAlignEnd = 'End';
  static const String rubyAlignJustify = 'Justify';
  static const String rubyAlignDistribute = 'Distribute';

  static const String rubyPositionBefore = 'Before';
  static const String rubyPositionAfter = 'After';
  static const String rubyPositionWarichu = 'Warichu';
  static const String rubyPositionInline = 'Inline';

  static const String glyphOrientationVerticalAuto = 'Auto';
  static const String glyphOrientationVerticalMinus180Degrees = '-180';
  static const String glyphOrientationVerticalMinus90Degrees = '-90';
  static const String glyphOrientationVerticalZeroDegrees = '0';
  static const String glyphOrientationVertical90Degrees = '90';
  static const String glyphOrientationVertical180Degrees = '180';
  static const String glyphOrientationVertical270Degrees = '270';
  static const String glyphOrientationVertical360Degrees = '360';

  PDLayoutAttributeObject() : super() {
    setOwner(ownerLayout);
  }

  PDLayoutAttributeObject.fromDictionary(COSDictionary dictionary)
      : super.fromDictionary(dictionary);

  String? get placement => getName(_placement);

  set placement(String? value) => setName(_placement, value);

  String? get writingMode => getName(_writingMode);

  set writingMode(String? value) => setName(_writingMode, value);

  PDGamma? get backgroundColor => getColor(_backgroundColor);

  set backgroundColor(PDGamma? value) => setColor(_backgroundColor, value);

  Object? get borderColors => getColorOrFourColors(_borderColor);

  void setAllBorderColors(PDGamma borderColor) =>
      setColor(_borderColor, borderColor);

  void setBorderColors(PDFourColours borderColors) =>
      setFourColors(_borderColor, borderColors);

  Object get borderStyle =>
      getNameOrArrayOfName(_borderStyle, borderStyleNone) ?? borderStyleNone;

  void setAllBorderStyles(String borderStyle) =>
      setName(_borderStyle, borderStyle);

  void setBorderStyles(List<String> borderStyles) =>
      setArrayOfName(_borderStyle, borderStyles);

  Object? get borderThickness => getNumberOrArrayOfNumber(
      _borderThickness, PDStandardAttributeObject.unspecified);

  void setAllBorderThicknesses(double borderThickness) =>
      setNumber(_borderThickness, borderThickness);

  void setAllBorderThicknessesInt(int borderThickness) =>
      setNumberInt(_borderThickness, borderThickness);

  void setBorderThicknesses(List<double> borderThicknesses) =>
      setArrayOfNumber(_borderThickness, borderThicknesses);

  Object? get padding =>
      getNumberOrArrayOfNumber(_padding, PDStandardAttributeObject.unspecified);

  void setAllPaddings(double padding) => setNumber(_padding, padding);

  void setAllPaddingsInt(int padding) => setNumberInt(_padding, padding);

  void setPaddings(List<double> paddings) =>
      setArrayOfNumber(_padding, paddings);

  PDGamma? get color => getColor(_color);

  set color(PDGamma? value) => setColor(_color, value);

  double get spaceBefore =>
      getNumber(_spaceBefore, PDStandardAttributeObject.unspecified);

  void setSpaceBefore(double spaceBefore) =>
      setNumber(_spaceBefore, spaceBefore);

  void setSpaceBeforeInt(int spaceBefore) =>
      setNumberInt(_spaceBefore, spaceBefore);

  double get spaceAfter =>
      getNumber(_spaceAfter, PDStandardAttributeObject.unspecified);

  void setSpaceAfter(double spaceAfter) => setNumber(_spaceAfter, spaceAfter);

  void setSpaceAfterInt(int spaceAfter) =>
      setNumberInt(_spaceAfter, spaceAfter);

  double get startIndent =>
      getNumber(_startIndent, PDStandardAttributeObject.unspecified);

  void setStartIndent(double startIndent) =>
      setNumber(_startIndent, startIndent);

  void setStartIndentInt(int startIndent) =>
      setNumberInt(_startIndent, startIndent);

  double get endIndent =>
      getNumber(_endIndent, PDStandardAttributeObject.unspecified);

  void setEndIndent(double endIndent) => setNumber(_endIndent, endIndent);

  void setEndIndentInt(int endIndent) =>
      setNumberInt(_endIndent, endIndent);

  double get textIndent =>
      getNumber(_textIndent, PDStandardAttributeObject.unspecified);

  void setTextIndent(double textIndent) => setNumber(_textIndent, textIndent);

  void setTextIndentInt(int textIndent) =>
      setNumberInt(_textIndent, textIndent);

  String? get textAlign => getName(_textAlign);

  set textAlign(String? value) => setName(_textAlign, value);

  PDRectangle? get bbox {
    final base = cosObject.getDictionaryObject(COSName.getPDFName(_bbox));
    if (base is COSArray) {
      return PDRectangle.fromCOSArray(base);
    }
    return null;
  }

  set bbox(PDRectangle? value) {
    final key = COSName.getPDFName(_bbox);
    if (value == null) {
      cosObject.setItem(key, null);
    } else {
      cosObject.setItem(key, value.toCOSArray());
    }
  }

  Object get width => getNumberOrName(_width, widthAuto);

  void setWidthAuto() => setName(_width, widthAuto);

  void setWidth(double width) => setNumber(_width, width);

  void setWidthInt(int width) => setNumberInt(_width, width);

  Object get height => getNumberOrName(_height, heightAuto);

  void setHeightAuto() => setName(_height, heightAuto);

  void setHeight(double height) => setNumber(_height, height);

  void setHeightInt(int height) => setNumberInt(_height, height);

  String? get blockAlign => getName(_blockAlign);

  set blockAlign(String? value) => setName(_blockAlign, value);

  String? get inlineAlign => getName(_inlineAlign);

  set inlineAlign(String? value) => setName(_inlineAlign, value);

  Object get tBorderStyle =>
      getNameOrArrayOfName(_tBorderStyle, borderStyleNone) ?? borderStyleNone;

  void setAllTBorderStyles(String tBorderStyle) =>
      setName(_tBorderStyle, tBorderStyle);

  void setTBorderStyles(List<String> tBorderStyles) =>
      setArrayOfName(_tBorderStyle, tBorderStyles);

  Object? get tPadding =>
      getNumberOrArrayOfNumber(_tPadding, PDStandardAttributeObject.unspecified);

  void setAllTPaddings(double tPadding) => setNumber(_tPadding, tPadding);

  void setAllTPaddingsInt(int tPadding) =>
      setNumberInt(_tPadding, tPadding);

  void setTPaddings(List<double> tPaddings) =>
      setArrayOfNumber(_tPadding, tPaddings);

  double get baselineShift => getNumber(_baselineShift, 0);

  void setBaselineShift(double value) => setNumber(_baselineShift, value);

  void setBaselineShiftInt(int value) => setNumberInt(_baselineShift, value);

  Object get lineHeight => getNumberOrName(_lineHeight, lineHeightNormal);

  void setLineHeightNormal() => setName(_lineHeight, lineHeightNormal);

  void setLineHeightAuto() => setName(_lineHeight, lineHeightAuto);

  void setLineHeight(double value) => setNumber(_lineHeight, value);

  void setLineHeightInt(int value) => setNumberInt(_lineHeight, value);

  PDGamma? get textDecorationColor => getColor(_textDecorationColor);

  set textDecorationColor(PDGamma? value) =>
      setColor(_textDecorationColor, value);

  double get textDecorationThickness =>
      getNumberOptional(_textDecorationThickness) ?? 0;

  void setTextDecorationThickness(double value) =>
      setNumber(_textDecorationThickness, value);

  void setTextDecorationThicknessInt(int value) =>
      setNumberInt(_textDecorationThickness, value);

  String? get textDecorationType => getName(_textDecorationType);

  set textDecorationType(String? value) =>
      setName(_textDecorationType, value);

  String? get rubyAlign => getName(_rubyAlign);

  set rubyAlign(String? value) => setName(_rubyAlign, value);

  String? get rubyPosition => getName(_rubyPosition);

  set rubyPosition(String? value) => setName(_rubyPosition, value);

  String? get glyphOrientationVertical => getName(_glyphOrientationVertical);

  set glyphOrientationVertical(String? value) =>
      setName(_glyphOrientationVertical, value);

  int get columnCount => getInteger(_columnCount, 1);

  set columnCount(int value) => setInteger(_columnCount, value);

  Object? get columnGap =>
      getNumberOrArrayOfNumber(_columnGap, PDStandardAttributeObject.unspecified);

  void setColumnGap(double value) => setNumber(_columnGap, value);

  void setColumnGapInt(int value) => setNumberInt(_columnGap, value);

  void setColumnGaps(List<double> values) =>
      setArrayOfNumber(_columnGap, values);

  Object? get columnWidths => getNumberOrArrayOfNumber(
      _columnWidths, PDStandardAttributeObject.unspecified);

  void setAllColumnWidths(double value) => setNumber(_columnWidths, value);

  void setAllColumnWidthsInt(int value) => setNumberInt(_columnWidths, value);

  void setColumnWidths(List<double> values) =>
      setArrayOfNumber(_columnWidths, values);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    if (isSpecified(_placement)) {
      buffer.write(', Placement=$placement');
    }
    if (isSpecified(_writingMode)) {
      buffer.write(', WritingMode=$writingMode');
    }
    if (isSpecified(_backgroundColor)) {
      buffer.write(', BackgroundColor=$backgroundColor');
    }
    if (isSpecified(_borderColor)) {
      buffer.write(', BorderColor=$borderColors');
    }
    if (isSpecified(_borderStyle)) {
      buffer.write(', BorderStyle=${_formatValue(borderStyle)}');
    }
    if (isSpecified(_borderThickness)) {
      buffer.write(', BorderThickness=${_formatValue(borderThickness)}');
    }
    if (isSpecified(_padding)) {
      buffer.write(', Padding=${_formatValue(padding)}');
    }
    if (isSpecified(_color)) {
      buffer.write(', Color=$color');
    }
    if (isSpecified(_spaceBefore)) {
      buffer.write(', SpaceBefore=$spaceBefore');
    }
    if (isSpecified(_spaceAfter)) {
      buffer.write(', SpaceAfter=$spaceAfter');
    }
    if (isSpecified(_startIndent)) {
      buffer.write(', StartIndent=$startIndent');
    }
    if (isSpecified(_endIndent)) {
      buffer.write(', EndIndent=$endIndent');
    }
    if (isSpecified(_textIndent)) {
      buffer.write(', TextIndent=$textIndent');
    }
    if (isSpecified(_textAlign)) {
      buffer.write(', TextAlign=$textAlign');
    }
    if (isSpecified(_bbox)) {
      buffer.write(', BBox=$bbox');
    }
    if (isSpecified(_width)) {
      buffer.write(', Width=$width');
    }
    if (isSpecified(_height)) {
      buffer.write(', Height=$height');
    }
    if (isSpecified(_blockAlign)) {
      buffer.write(', BlockAlign=$blockAlign');
    }
    if (isSpecified(_inlineAlign)) {
      buffer.write(', InlineAlign=$inlineAlign');
    }
    if (isSpecified(_tBorderStyle)) {
      buffer.write(', TBorderStyle=${_formatValue(tBorderStyle)}');
    }
    if (isSpecified(_tPadding)) {
      buffer.write(', TPadding=${_formatValue(tPadding)}');
    }
    if (isSpecified(_baselineShift)) {
      buffer.write(', BaselineShift=$baselineShift');
    }
    if (isSpecified(_lineHeight)) {
      buffer.write(', LineHeight=$lineHeight');
    }
    if (isSpecified(_textDecorationColor)) {
      buffer.write(', TextDecorationColor=$textDecorationColor');
    }
    if (isSpecified(_textDecorationThickness)) {
      buffer.write(', TextDecorationThickness=$textDecorationThickness');
    }
    if (isSpecified(_textDecorationType)) {
      buffer.write(', TextDecorationType=$textDecorationType');
    }
    if (isSpecified(_rubyAlign)) {
      buffer.write(', RubyAlign=$rubyAlign');
    }
    if (isSpecified(_rubyPosition)) {
      buffer.write(', RubyPosition=$rubyPosition');
    }
    if (isSpecified(_glyphOrientationVertical)) {
      buffer.write(', GlyphOrientationVertical=$glyphOrientationVertical');
    }
    if (isSpecified(_columnCount)) {
      buffer.write(', ColumnCount=$columnCount');
    }
    if (isSpecified(_columnGap)) {
      buffer.write(', ColumnGap=${_formatValue(columnGap)}');
    }
    if (isSpecified(_columnWidths)) {
      buffer.write(', ColumnWidths=${_formatValue(columnWidths)}');
    }
    return buffer.toString();
  }

  String _formatValue(Object? value) {
    if (value is List) {
      return '[${value.join(', ')}]';
    }
    return value?.toString() ?? 'null';
  }
}

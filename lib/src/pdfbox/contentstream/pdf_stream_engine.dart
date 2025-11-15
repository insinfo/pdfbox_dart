library pdfbox.contentstream.pdf_stream_engine;

import 'package:logging/logging.dart';

import '../cos/cos_array.dart';
import '../cos/cos_base.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_number.dart';
import '../cos/cos_string.dart';
import '../pdfparser/pdf_stream_parser.dart';
import '../pdmodel/pd_page.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/graphics/color/pd_color.dart';
import '../pdmodel/graphics/color/pd_color_space.dart';
import '../pdmodel/graphics/color/pd_device_cmyk.dart';
import '../pdmodel/graphics/color/pd_device_gray.dart';
import '../pdmodel/graphics/color/pd_device_rgb.dart';
import '../pdmodel/graphics/color/pd_pattern_color_space.dart';
import '../pdmodel/graphics/form/pd_form_xobject.dart';
import '../pdmodel/graphics/pd_line_dash_pattern.dart';
import '../pdmodel/graphics/pd_post_script_xobject.dart';
import '../pdmodel/graphics/pdxobject.dart';
import '../pdmodel/graphics/state/pd_graphics_state.dart';
import '../pdmodel/graphics/state/pd_text_state.dart';
import '../pdmodel/graphics/state/rendering_intent.dart';
import '../pdmodel/graphics/state/rendering_mode.dart';
import '../pdmodel/graphics/shading/pd_shading.dart';
import '../pdmodel/resource_cache.dart';
import '../util/matrix.dart';
import 'operator/operator.dart';
import 'operator/operator_name.dart';
import 'pd_content_stream.dart';

part 'operators/begin_text.dart';
part 'operators/end_text.dart';
part 'operators/invoke_xobject.dart';
part 'operators/move_text.dart';
part 'operators/save_restore_state.dart';
part 'operators/set_font.dart';
part 'operators/set_text_matrix.dart';
part 'operators/show_text.dart';
part 'operators/text_state.dart';
part 'operators/graphics_state.dart';
part 'operators/path_construction.dart';
part 'operators/path_painting.dart';
part 'operators/clip.dart';
part 'operators/color.dart';
part 'operators/marked_content.dart';
part 'operators/shading.dart';
part 'operators/type3.dart';

enum PathWindingRule { nonZero, evenOdd }

/// Core interpreter for PDF content streams, ported from PDFBox's
/// `PDFStreamEngine`. The implementation focuses on extensibility so callers can
/// override hooks or register additional operator processors as modules mature.
class PDFStreamEngine {
  PDFStreamEngine({Iterable<OperatorProcessor>? operators})
      : _logger = Logger('pdfbox.PDFStreamEngine') {
    final initialOperators = operators ?? _createDefaultOperatorProcessors();
    registerOperatorProcessors(initialOperators);
  }

  final Logger _logger;
  final Map<String, OperatorProcessor> _operatorProcessors =
      <String, OperatorProcessor>{};
  final List<COSBase> _operands = <COSBase>[];
  final List<PDResources> _resourceStack = <PDResources>[];
  final List<PDGraphicsState> _graphicsStack = <PDGraphicsState>[];

  PDPage? _currentPage;
  ResourceCache? _resourceCache;
  bool _shouldProcessColorOperators = true;

  PDGraphicsState? get currentGraphicsState =>
      _graphicsStack.isEmpty ? null : _graphicsStack.last;

  PDGraphicsState _ensureGraphicsState() {
    if (_graphicsStack.isEmpty) {
      _graphicsStack.add(PDGraphicsState());
    }
    return _graphicsStack.last;
  }

  /// Processes all content streams associated with [page].
  void processPage(PDPage page) {
    _currentPage = page;
    _resourceCache = page.resourceCache;
    _graphicsStack
      ..clear()
      ..add(PDGraphicsState());
    _currentFontName = null;
    try {
      final pageResources = page.resources;
      for (final stream in page.contentStreams) {
        processContentStream(stream, pageResources);
      }
    } finally {
      _resourceStack.clear();
      _graphicsStack.clear();
      _currentFontName = null;
      _currentPage = null;
      _resourceCache = null;
    }
  }

  /// Interprets [contentStream] using the supplied [resources].
  void processContentStream(PDContentStream contentStream, PDResources resources) {
    final parser = PDFStreamParser(contentStream);
    final tokens = parser.parse();
    _ensureGraphicsState();
    _pushResources(resources);
    try {
      _processTokens(tokens);
    } finally {
      _popResources();
    }
  }

  /// Registers a single operator [processor].
  void registerOperatorProcessor(OperatorProcessor processor) {
    processor._setContext(this);
    _operatorProcessors[processor.operator] = processor;
  }

  /// Registers multiple operator processors.
  void registerOperatorProcessors(Iterable<OperatorProcessor> processors) {
    for (final processor in processors) {
      registerOperatorProcessor(processor);
    }
  }

  /// Returns the processor registered for [name], if any.
  OperatorProcessor? getOperatorProcessor(String name) =>
      _operatorProcessors[name];

  /// Exposes the active resource dictionary for subclasses and operators.
  PDResources? get resources => currentResources;

  /// Indicates whether color-changing operators should be processed.
  bool get shouldProcessColorOperators => _shouldProcessColorOperators;

  /// Controls processing of color operators (used by Type3 and patterns).
  void setShouldProcessColorOperators(bool value) {
    _shouldProcessColorOperators = value;
  }

  COSName? _currentFontName;

  COSName? get currentFontName => _currentFontName;

  /// Hook invoked when a `BT` operator is read.
  void beginText() {
    final state = _ensureGraphicsState();
    state.textMatrix = Matrix();
    state.textLineMatrix = Matrix();
  }

  /// Hook invoked when an `ET` operator is read.
  void endText() {}

  /// Hook invoked when a `Tf` operator sets the active font.
  void setFont(COSName fontName, double fontSize) {
    final state = _ensureGraphicsState();
    final PDTextState textState = state.textState;
    textState.fontSize = fontSize;
    _currentFontName = fontName;
  }

  /// Hook invoked when a `Td`/`TD` operator adjusts the text position.
  void moveText(double tx, double ty) {
    final state = _ensureGraphicsState();
    final Matrix lineMatrix = state.textLineMatrix ?? Matrix();
    lineMatrix.translate(tx, ty);
    state.textLineMatrix = lineMatrix;
    state.textMatrix = lineMatrix.clone();
  }

  /// Hook invoked when text leading is set via `TD`.
  void setTextLeading(double leading) {
    final state = _ensureGraphicsState();
    state.textState.leading = leading;
  }

  /// Hook invoked when a `T*` operator moves to the next text line.
  void nextLine() {
    final state = _ensureGraphicsState();
    final leading = state.textState.leading;
    moveText(0, -leading);
  }

  /// Hook invoked when a `Tm` operator sets the text matrix.
  void setTextMatrix(
      double a, double b, double c, double d, double e, double f) {
    final state = _ensureGraphicsState();
    final matrix = Matrix.fromComponents(a, b, c, d, e, f);
    state.textMatrix = matrix;
    state.textLineMatrix = matrix.clone();
  }

  /// Hook invoked when the character spacing is adjusted via `Tc`.
  void setCharacterSpacing(double spacing) {
    final state = _ensureGraphicsState();
    state.textState.characterSpacing = spacing;
  }

  /// Hook invoked when the word spacing is adjusted via `Tw`.
  void setWordSpacing(double spacing) {
    final state = _ensureGraphicsState();
    state.textState.wordSpacing = spacing;
  }

  /// Hook invoked when the horizontal scaling changes via `Tz`.
  void setHorizontalScaling(double scale) {
    final state = _ensureGraphicsState();
    state.textState.horizontalScaling = scale;
  }

  /// Hook invoked when text rendering mode is updated via `Tr`.
  void setTextRenderingMode(int mode) {
    if (mode < 0 || mode >= RenderingMode.values.length) {
      return;
    }
    final state = _ensureGraphicsState();
    state.textState.renderingMode = RenderingMode.values[mode];
  }

  /// Hook invoked when the text rise changes via `Ts`.
  void setTextRise(double rise) {
    final state = _ensureGraphicsState();
    state.textState.rise = rise;
  }

  /// Hook invoked for simple `Tj` operators.
  void showTextString(COSString text) {}

  /// Hook invoked for `TJ` operators containing arrays of strings/numbers.
  void showTextStrings(COSArray array) {
    for (final element in array) {
      if (element is COSString) {
        showTextString(element);
      } else if (element is COSNumber) {
        applyTextAdjustment(element.doubleValue);
      }
    }
  }

  /// Applies the text displacement introduced by `TJ` arrays.
  void applyTextAdjustment(double adjustment) {
    final state = _ensureGraphicsState();
    final PDTextState textState = state.textState;
    final horizontalScaling = textState.horizontalScaling / 100.0;
    final fontSize = textState.fontSize;
    final tx = -adjustment / 1000.0 * fontSize * horizontalScaling;
    final Matrix textMatrix = state.textMatrix ?? Matrix();
    textMatrix.translate(tx, 0);
    state.textMatrix = textMatrix;
  }

  /// Hook invoked when a `'` operator moves to the next line and shows text.
  void showTextLine(COSString text) {
    nextLine();
    showTextString(text);
  }

  /// Hook invoked when a `"` operator sets spacing, moves, and shows text.
  void showTextLineAndSpacing(
      double wordSpacing, double characterSpacing, COSString text) {
    setWordSpacing(wordSpacing);
    setCharacterSpacing(characterSpacing);
    showTextLine(text);
  }

  /// Hook invoked after a graphics state `q` operator.
  void pushGraphicsState() {
    final state = _ensureGraphicsState();
    _graphicsStack.add(state.clone());
  }

  /// Hook invoked after a graphics state `Q` operator.
  void popGraphicsState() {
    if (_graphicsStack.length <= 1) {
      _logger.warning('Graphics state stack underflow');
      return;
    }
    _graphicsStack.removeLast();
  }

  /// Hook invoked when a `cm` operator concatenates a transformation matrix.
  void concatenateMatrix(
      double a, double b, double c, double d, double e, double f) {
    final state = _ensureGraphicsState();
    final matrix = Matrix.fromComponents(a, b, c, d, e, f);
    state.currentTransformationMatrix.concatenate(matrix);
  }

  /// Hook invoked when a line width (`w`) operator is read.
  void setLineWidth(double width) {
    final state = _ensureGraphicsState();
    state.lineWidth = width;
  }

  /// Hook invoked when a line cap (`J`) operator is read.
  void setLineCap(int lineCap) {
    final state = _ensureGraphicsState();
    state.lineCap = lineCap;
  }

  /// Hook invoked when a line join (`j`) operator is read.
  void setLineJoin(int lineJoin) {
    final state = _ensureGraphicsState();
    state.lineJoin = lineJoin;
  }

  /// Hook invoked when a miter limit (`M`) operator is read.
  void setMiterLimit(double limit) {
    final state = _ensureGraphicsState();
    state.miterLimit = limit;
  }

  /// Hook invoked when a dash pattern (`d`) operator is read.
  void setLineDashPattern(COSArray dashArray, double phase) {
    final state = _ensureGraphicsState();
    state.setLineDashPattern(
      PDLineDashPattern.fromCOSArray(dashArray, phase.toInt()),
    );
  }

  /// Hook invoked when a rendering intent (`ri`) operator is read.
  void setRenderingIntent(COSName intentName) {
    final state = _ensureGraphicsState();
    state.setRenderingIntent(RenderingIntent.fromString(intentName.name));
  }

  /// Hook invoked when a flatness tolerance (`i`) operator is read.
  void setFlatnessTolerance(double flatness) {
    final state = _ensureGraphicsState();
    state.flatness = flatness;
  }

  /// Hook invoked when a smoothness tolerance (`sm`) operator is read.
  void setSmoothnessTolerance(double smoothness) {
    final state = _ensureGraphicsState();
    state.smoothness = smoothness;
  }

  /// Hook invoked when a `gs` operator applies an ExtGState.
  void setGraphicsStateParameters(COSName dictionaryName) {
    final resources = currentResources;
    if (resources == null) {
      _logger.warning(
          "Ignoring 'gs' operator without resources for $dictionaryName");
      return;
    }
    final extGState = resources.getExtGState(dictionaryName);
    if (extGState == null) {
      _logger.warning("ExtGState '$dictionaryName' missing from resources");
      return;
    }
    final state = _ensureGraphicsState();
    extGState.copyIntoGraphicsState(state);
  }

  /// Called when a path move-to (`m`) operator is read.
  void moveTo(double x, double y) {}

  /// Called when a path line-to (`l`) operator is read.
  void lineTo(double x, double y) {}

  /// Called when a cubic curve (`c`) operator is read.
  void curveTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {}

  /// Called when a cubic curve with a replicated first control point (`v`) is read.
  void curveToReplicateInitialPoint(
      double x2, double y2, double x3, double y3) {}

  /// Called when a cubic curve with a replicated final control point (`y`) is read.
  void curveToReplicateFinalPoint(
      double x1, double y1, double x3, double y3) {}

  /// Called when a close path (`h`) operator is read.
  void closePath() {}

  /// Called when a rectangle (`re`) operator is read.
  void appendRectangle(double x, double y, double width, double height) {}

  /// Called when a `S` or `s` operator is read.
  void strokePath({bool close = false}) {}

  /// Called when an `f`, `F`, or `f*` operator is read.
  void fillPath(PathWindingRule rule, {bool close = false}) {}

  /// Called when a `B`, `B*`, `b`, or `b*` operator is read.
  void fillAndStrokePath(PathWindingRule rule, {bool close = false}) {}

  /// Called when an `n` operator is read.
  void endPath() {}

  /// Called when a clipping operator (`W`/`W*`) is read.
  void clipPath(PathWindingRule rule) {}

  /// Called when a marked-content sequence begins.
  void beginMarkedContentSequence(
    COSName tag,
    COSDictionary? properties,
  ) {
    // TODO: Track marked content stack once higher-level consumers exist.
  }

  /// Called when a marked-content sequence ends.
  void endMarkedContentSequence() {}

  /// Called for marked-content point operators (MP/DP).
  void markedContentPoint(COSName tag, COSDictionary? properties) {}

  /// Called when a Type 3 charproc specifies glyph width.
  void setType3GlyphWidth(double wx, double wy) {
    // TODO: Wire glyph width to Type3 font infrastructure when available.
  }

  /// Called when a Type 3 charproc specifies glyph width and bbox.
  void setType3GlyphWidthAndBoundingBox(
    double wx,
    double wy,
    double llx,
    double lly,
    double urx,
    double ury,
  ) {
    setType3GlyphWidth(wx, wy);
    // TODO: Persist Type3 glyph bounding box for future rendering.
  }

  /// Resolves a shading resource and delegates rendering.
  void shadingFill(COSName resourceName) {
    final resources = currentResources;
    if (resources == null) {
      _logger.warning("Skipping 'sh' without available resources");
      return;
    }
    final shading = resources.getShading(resourceName);
    if (shading == null) {
      _logger.warning(
          () => "Shading '${resourceName.name}' missing from resources");
      return;
    }
    processShading(shading);
  }

  /// Hook invoked to process an actual shading resource.
  void processShading(PDShading shading) {
    // TODO: Implement shading rendering once graphics engine is ported.
  }

  /// Sets the stroking colour space via `CS`.
  void setStrokingColorSpace(PDColorSpace colorSpace) {
    final state = _ensureGraphicsState();
    state.strokingColorSpace = colorSpace;
    state.strokingColor = colorSpace.getInitialColor();
  }

  /// Sets the non-stroking colour space via `cs`.
  void setNonStrokingColorSpace(PDColorSpace colorSpace) {
    final state = _ensureGraphicsState();
    state.nonStrokingColorSpace = colorSpace;
    state.nonStrokingColor = colorSpace.getInitialColor();
  }

  /// Sets stroking colour components via `SC`/`SCN`.
  void setStrokingColor(List<double> components, {COSName? patternName}) {
    _setColor(true, components, patternName: patternName);
  }

  /// Sets non-stroking colour components via `sc`/`scn`.
  void setNonStrokingColor(List<double> components, {COSName? patternName}) {
    _setColor(false, components, patternName: patternName);
  }

  /// Sets stroking DeviceGray colour via `G`.
  void setStrokingGray(double gray) {
    final state = _ensureGraphicsState();
    state.strokingColorSpace = PDDeviceGray.instance;
    state.strokingColor =
        PDColor(<double>[gray], PDDeviceGray.instance);
  }

  /// Sets non-stroking DeviceGray colour via `g`.
  void setNonStrokingGray(double gray) {
    final state = _ensureGraphicsState();
    state.nonStrokingColorSpace = PDDeviceGray.instance;
    state.nonStrokingColor =
        PDColor(<double>[gray], PDDeviceGray.instance);
  }

  /// Sets stroking DeviceRGB colour via `RG`.
  void setStrokingRGB(double r, double g, double b) {
    final state = _ensureGraphicsState();
    state.strokingColorSpace = PDDeviceRGB.instance;
    state.strokingColor =
        PDColor(<double>[r, g, b], PDDeviceRGB.instance);
  }

  /// Sets non-stroking DeviceRGB colour via `rg`.
  void setNonStrokingRGB(double r, double g, double b) {
    final state = _ensureGraphicsState();
    state.nonStrokingColorSpace = PDDeviceRGB.instance;
    state.nonStrokingColor =
        PDColor(<double>[r, g, b], PDDeviceRGB.instance);
  }

  /// Sets stroking DeviceCMYK colour via `K`.
  void setStrokingCMYK(double c, double m, double y, double k) {
    final state = _ensureGraphicsState();
    state.strokingColorSpace = PDDeviceCMYK.instance;
    state.strokingColor =
        PDColor(<double>[c, m, y, k], PDDeviceCMYK.instance);
  }

  /// Sets non-stroking DeviceCMYK colour via `k`.
  void setNonStrokingCMYK(double c, double m, double y, double k) {
    final state = _ensureGraphicsState();
    state.nonStrokingColorSpace = PDDeviceCMYK.instance;
    state.nonStrokingColor =
        PDColor(<double>[c, m, y, k], PDDeviceCMYK.instance);
  }

  void _setColor(bool stroking, List<double> components,
      {COSName? patternName}) {
    final state = _ensureGraphicsState();
    final PDColorSpace colorSpace = stroking
        ? state.strokingColorSpace
        : state.nonStrokingColorSpace;

    if (colorSpace is PDPatternColorSpace) {
      setPatternColor(
        stroking: stroking,
        colorSpace: colorSpace,
        components: components,
        patternName: patternName,
      );
      return;
    }

    final color = PDColor(components, colorSpace);
    if (stroking) {
      state.strokingColor = color;
    } else {
      state.nonStrokingColor = color;
    }
  }

  /// Hook invoked for pattern colours; subclasses may override.
  void setPatternColor({
    required bool stroking,
    required PDPatternColorSpace colorSpace,
    required List<double> components,
    COSName? patternName,
  }) {
    final state = _ensureGraphicsState();
    final color = PDColor(components, colorSpace);
    if (stroking) {
      state.strokingColor = color;
    } else {
      state.nonStrokingColor = color;
    }
  }

  PDColorSpace? resolveColorSpace(COSBase colorSpace) {
    try {
      return PDColorSpace.create(colorSpace, resources: currentResources);
    } on UnsupportedError catch (error) {
      _logger.warning(error.toString());
    }
    return null;
  }

  /// Hook invoked when an XObject is drawn.
  void processXObject(COSName objectName) {
    final resources = currentResources;
    if (resources == null) {
      return;
    }
    final xObject = resources.getXObject(objectName);
    if (xObject == null) {
      _logger.warning(() => "Skipping unknown XObject '$objectName'");
      return;
    }
    if (xObject is PDFormXObject) {
      processFormXObject(xObject);
      return;
    }
    if (xObject is PDImageXObject) {
      processImageXObject(objectName, xObject);
      return;
    }
    if (xObject is PDPostScriptXObject) {
      processPostScriptXObject(objectName, xObject);
      return;
    }
    processExternalObject(objectName, xObject);
  }

  /// Hook invoked for form XObjects (type `/Form`).
  void processFormXObject(PDFormXObject form) {
    final formResources = form.resources ?? currentResources;
    if (formResources == null) {
      _logger.warning('Form XObject without resources ignored');
      return;
    }
    form.resourceCache ??= _resourceCache;
    processContentStream(form, formResources);
  }

  /// Hook invoked for image XObjects (type `/Image`).
  void processImageXObject(COSName name, PDImageXObject image) {}

  /// Hook invoked for PostScript XObjects.
  void processPostScriptXObject(
      COSName name, PDPostScriptXObject postScript) {}

  /// Hook invoked for any other type of XObject.
  void processExternalObject(COSName name, PDXObject object) {}

  PDResources? get currentResources =>
      _resourceStack.isEmpty ? null : _resourceStack.last;

  PDPage? get currentPage => _currentPage;

  void unsupportedOperator(Operator operator, List<COSBase> operands) {}

  void _processTokens(List<Object?> tokens) {
    var index = 0;
    while (index < tokens.length) {
      final token = tokens[index];
      if (token is COSBase) {
        _operands.add(token);
        index++;
        continue;
      }
      if (token is Operator) {
        var additionalConsumed = 0;
        if (_operands.isEmpty && token.name == OperatorName.showTextLine) {
          final nextIndex = index + 1;
          if (nextIndex < tokens.length && tokens[nextIndex] is COSString) {
            _operands.add(tokens[nextIndex] as COSString);
            additionalConsumed = 1;
          }
        } else if (token.name == OperatorName.showTextLineAndSpace &&
            _operands.length == 2 &&
            _operands[0] is COSNumber &&
            _operands[1] is COSNumber) {
          final nextIndex = index + 1;
          if (nextIndex < tokens.length && tokens[nextIndex] is COSString) {
            _operands.add(tokens[nextIndex] as COSString);
            additionalConsumed = 1;
          }
        }
        _processOperator(token);
        index += 1 + additionalConsumed;
        continue;
      }
      if (token != null) {
        _logger.fine('Ignoring unexpected token type ${token.runtimeType}');
      }
      index++;
    }
  }

  void _processOperator(Operator operator) {
    final operands = List<COSBase>.unmodifiable(_operands);
    _operands.clear();
    final processor = _operatorProcessors[operator.name];
    if (processor != null) {
      processor.process(operator, operands);
    } else {
      unsupportedOperator(operator, operands);
    }
  }

  void _pushResources(PDResources resources) {
    _resourceStack.add(resources);
  }

  void _popResources() {
    if (_resourceStack.isNotEmpty) {
      _resourceStack.removeLast();
    }
  }

  static Iterable<OperatorProcessor> _createDefaultOperatorProcessors() =>
      <OperatorProcessor>[
        BeginTextOperator(),
        EndTextOperator(),
        SetFontOperator(),
        ShowTextOperator(),
        ShowTextArrayOperator(),
        ShowTextLineOperator(),
        ShowTextLineAndSpaceOperator(),
        MoveTextOperator(),
        MoveTextSetLeadingOperator(),
        NextLineOperator(),
        SetTextMatrixOperator(),
        ConcatMatrixOperator(),
        SetTextLeadingOperator(),
        SetCharSpacingOperator(),
        SetWordSpacingOperator(),
        SetTextHorizontalScalingOperator(),
        SetTextRenderingModeOperator(),
        SetTextRiseOperator(),
        SaveGraphicsStateOperator(),
        RestoreGraphicsStateOperator(),
        SetLineWidthOperator(),
        SetLineCapOperator(),
        SetLineJoinOperator(),
        SetMiterLimitOperator(),
        SetLineDashOperator(),
        SetRenderingIntentOperator(),
        SetFlatnessOperator(),
        SetSmoothnessOperator(),
        SetGraphicsStateOperator(),
        MoveToOperator(),
        LineToOperator(),
        CurveToOperator(),
        CurveToReplicateInitialPointOperator(),
        CurveToReplicateFinalPointOperator(),
        ClosePathOperator(),
        RectangleOperator(),
        StrokePathOperator(),
        CloseStrokePathOperator(),
        FillPathOperator(),
        FillAlternativeOperator(),
        FillEvenOddOperator(),
        FillAndStrokeOperator(),
        FillEvenOddAndStrokeOperator(),
        CloseFillAndStrokeOperator(),
        CloseFillEvenOddAndStrokeOperator(),
        EndPathOperator(),
        ClipPathOperator(),
        ClipEvenOddOperator(),
        SetStrokingColorSpaceOperator(),
        SetNonStrokingColorSpaceOperator(),
        SetStrokingColorOperator(),
        SetNonStrokingColorOperator(),
        SetStrokingColorNOPatternOperator(),
        SetNonStrokingColorNOPatternOperator(),
        SetStrokingGrayOperator(),
        SetNonStrokingGrayOperator(),
        SetStrokingRGBOperator(),
        SetNonStrokingRGBOperator(),
        SetStrokingCMYKOperator(),
        SetNonStrokingCMYKOperator(),
        BeginMarkedContentOperator(),
        BeginMarkedContentWithPropertiesOperator(),
        EndMarkedContentOperator(),
        MarkedContentPointOperator(),
        MarkedContentPointWithPropertiesOperator(),
        ShadingFillOperator(),
        Type3SetCharWidthOperator(),
        Type3SetCharWidthAndBoundingBoxOperator(),
        InvokeXObjectOperator(),
      ];
}

/// Base contract for operator processors.
abstract class OperatorProcessor {
  OperatorProcessor(this.operator);

  final String operator;
  PDFStreamEngine? _context;

  PDFStreamEngine get context => _context!;

  void _setContext(PDFStreamEngine engine) {
    _context = engine;
  }

  void process(Operator operator, List<COSBase> operands);

  T _expectOperand<T extends COSBase>(List<COSBase> operands, int index) {
    if (index < 0 || index >= operands.length) {
      throw StateError(
          'Operator $operator expects operand at index $index but only ${operands.length} present');
    }
    final operand = operands[index];
    if (operand is! T) {
      throw StateError(
          'Operand $index for operator $operator must be ${T.runtimeType} but was ${operand.runtimeType}');
    }
    return operand;
  }
}
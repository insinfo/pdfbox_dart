import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import '../contentstream/pdf_graphics_stream_engine.dart';
import '../contentstream/pdf_stream_engine.dart' show PathWindingRule;
import '../cos/cos_array.dart';
import '../cos/cos_boolean.dart';
import '../cos/cos_name.dart';
import '../cos/cos_number.dart';
import '../cos/cos_string.dart';
import '../filter/decode_options.dart';
import '../pdmodel/font/pd_type0_font.dart';
import '../pdmodel/font/pd_type3_font.dart';
import '../pdmodel/font/pd_vector_font.dart';
import '../pdmodel/font/pdfont.dart';
import '../pdmodel/font/pdfont_factory.dart';
import '../pdmodel/graphics/state/pd_graphics_state.dart';
import '../pdmodel/common/pd_rectangle.dart';
import '../pdmodel/graphics/color/pd_color.dart';
import '../pdmodel/graphics/color/pd_pattern_color_space.dart';
import '../pdmodel/graphics/color/pd_raster.dart';
import '../pdmodel/graphics/pdxobject.dart';
import '../pdmodel/graphics/form/pd_form_xobject.dart';
import '../pdmodel/graphics/state/pd_soft_mask.dart';
import '../pdmodel/graphics/blend/blend_mode.dart' as pdf_blend;
import '../pdmodel/graphics/pattern/pd_abstract_pattern.dart';
import '../pdmodel/graphics/pattern/pd_tiling_pattern.dart';
import '../pdmodel/graphics/shading/pd_shading.dart';
import '../pdmodel/common/function/pdf_function.dart';
import '../pdmodel/pd_resources.dart';
import '../pdmodel/pd_stream.dart';
import '../util/matrix.dart';
import 'page_drawer_parameters.dart';
import 'glyph_cache.dart';
import 'tiling_paint_factory.dart';
import 'group_graphics.dart';
import 'soft_mask.dart';
import '../pdmodel/interactive/annotation/pd_annotation.dart';

import '../../io/random_access_read_buffer.dart';

enum _BlendModeLite {
  clear,
  src,
  dst,
  srcOver,
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcAtop,
  dstAtop,
  xor,
  add,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
}

enum _PorterDuff {
  clear,
  src,
  dst,
  srcOver,
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcAtop,
  dstAtop,
  xor,
}

enum _BlendFn {
  add,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
}

/// Port of PDFBox's `PageDrawer`.
///
/// This implementation targets `dart_graphics`'s `Graphics2D`.
///
/// Note: this is an incremental port. Missing features (patterns, shadings,
/// advanced text, transparency) are left as TODOs to preserve a
/// PDFBox-compatible structure.
class PageDrawer extends PDFGraphicsStreamEngine {
  PageDrawer(this._parameters) : super() {}

  static final Logger _log = Logger('pdfbox.rendering.PageDrawer');

  final PageDrawerParameters _parameters;

  late Graphics2D _graphics;
  late Affine _xform;
  late PDRectangle _pageSize;

  final List<_ClipEntry> _clipEntries = <_ClipEntry>[];
  final List<int> _clipDepthStack = <int>[];

  int _clipVersion = 0;
  int _clipMaskVersion = -1;
  ImageBuffer? _clipMask;
  _IntRect? _clipBounds;

  PDSoftMask? _softMaskCacheKey;
  ImageBuffer? _softMaskCacheMask;
  _IntRect? _softMaskCacheBBoxDevice;

  final Map<PDFont, GlyphCache> _glyphCaches = <PDFont, GlyphCache>{};
  final Map<PDFont, PDFont> _vectorFontFallbacks = <PDFont, PDFont>{};

  bool _processingType3CharProc = false;
  double? _type3CharProcWidthWx;
  double? _type3CharProcWidthWy;

  /// Draws the page using the supplied Graphics2D.
  void drawPage(Graphics2D graphics, PDRectangle pageSize) {
    _graphics = graphics;
    _xform = _cloneAffine(graphics.transform);
    _pageSize = pageSize;
    _clipEntries.clear();
    _clipDepthStack.clear();
    _clipVersion = 0;
    _clipMaskVersion = -1;
    _clipMask = null;
    _clipBounds = null;
    _softMaskCacheKey = null;
    _softMaskCacheMask = null;
    _softMaskCacheBBoxDevice = null;
    _glyphCaches.clear();
    _syncTransform();

    final page = _parameters.getPage();
    processPage(page);

    // Render annotations after page content
    for (final annotation in page.annotations) {
      if (!_shouldSkipAnnotation(annotation)) {
        showAnnotation(annotation);
      }
    }
  }

  /// Returns true if the given annotation should not be rendered.
  bool _shouldSkipAnnotation(PDAnnotation annotation) {
    // Skip invisible/hidden annotations
    if (annotation.isInvisible || annotation.isHidden) {
      return true;
    }
    // Skip NoView annotations (visible only when interacting)
    if (annotation.isNoView) {
      return true;
    }
    return false;
  }

  // NOTE on transform composition:
  // `dart_graphics`' `Affine.multiply(m)` composes so that `m` is applied LAST
  // on points (i.e. `(a.multiply(b))(p) == b(a(p))`). This is easy to get
  // backwards when porting from PDFBox/Java2D.
  // Also note: `Affine.translate/rotate/scale` follow AGG's pre-multiply
  // semantics (they act on the existing matrix like in agg::trans_affine).
  // See test/dart_graphics/affine_multiply_test.dart for a minimal proof.

  Graphics2D getGraphics() => _graphics;

  PDRectangle getPageSize() => _pageSize;

  @override
  void pushGraphicsState() {
    super.pushGraphicsState();
    _graphics.save();
    _clipDepthStack.add(_clipEntries.length);
    _syncTransform();
  }

  @override
  void popGraphicsState() {
    super.popGraphicsState();
    _graphics.restore();
    if (_clipDepthStack.isNotEmpty) {
      final targetLen = _clipDepthStack.removeLast();
      if (targetLen < _clipEntries.length) {
        _clipEntries.removeRange(targetLen, _clipEntries.length);
        _invalidateClipMask();
      }
    }
    _syncTransform();
  }

  @override
  void concatenateMatrix(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
  ) {
    super.concatenateMatrix(a, b, c, d, e, f);
    _syncTransform();
  }

  @override
  void setType3GlyphWidth(double wx, double wy) {
    if (!_processingType3CharProc) {
      return;
    }
    // d0/d1 are specified once per charproc; keep the first.
    _type3CharProcWidthWx ??= wx;
    _type3CharProcWidthWy ??= wy;
  }

  @override
  void setType3GlyphWidthAndBoundingBox(
    double wx,
    double wy,
    double llx,
    double lly,
    double urx,
    double ury,
  ) {
    setType3GlyphWidth(wx, wy);
  }

  @override
  void strokePath({bool close = false}) {
    final state = currentGraphicsState;
    if (state == null) {
      resetLinePath();
      return;
    }

    if (close) {
      getLinePath().closePath();
    }

    final lineWidth = state.lineWidth;
    if (lineWidth <= 0) {
      resetLinePath();
      return;
    }

    _drawWithClip((_, __) {
      final state = currentGraphicsState;
      if (state == null) {
        return;
      }

      if (_isPatternColor(state.strokingColor)) {
        _strokeCurrentPathWithPattern(state.strokingColor);
        return;
      }

      _syncPaintStateForStroke();
      _setFillRule(PathWindingRule.nonZero);
      _graphics.beginPath();
      _graphics.currentPath.concat(getLinePath());
      _graphics.strokePath();
    });
    resetLinePath();
  }

  @override
  void fillPath(PathWindingRule rule, {bool close = false}) {
    final state = currentGraphicsState;
    if (state == null) {
      resetLinePath();
      return;
    }

    if (close) {
      getLinePath().closePath();
    }

    _drawWithClip((_, __) {
      final state = currentGraphicsState;
      if (state == null) {
        return;
      }

      if (_isPatternColor(state.nonStrokingColor)) {
        _fillCurrentPathWithPattern(rule, state.nonStrokingColor);
        return;
      }

      _syncPaintStateForFill();
      _setFillRule(rule);
      _graphics.beginPath();
      _graphics.currentPath.concat(getLinePath());
      _graphics.fillPath();
    });
    resetLinePath();
  }

  @override
  void fillAndStrokePath(PathWindingRule rule, {bool close = false}) {
    final state = currentGraphicsState;
    if (state == null) {
      resetLinePath();
      return;
    }

    if (close) {
      getLinePath().closePath();
    }

    _drawWithClip((_, __) {
      final state = currentGraphicsState;
      if (state == null) {
        return;
      }

      // Match PDFBox order: fill then stroke.
      if (_isPatternColor(state.nonStrokingColor)) {
        _fillCurrentPathWithPattern(rule, state.nonStrokingColor);
      } else {
        _graphics.beginPath();
        _graphics.currentPath.concat(getLinePath());
        _syncPaintStateForFill();
        _setFillRule(rule);
        _graphics.fillPath();
      }

      if (_isPatternColor(state.strokingColor)) {
        _strokeCurrentPathWithPattern(state.strokingColor);
      } else {
        _syncPaintStateForStroke();
        _graphics.beginPath();
        _graphics.currentPath.concat(getLinePath());
        _graphics.strokePath();
      }
    });

    resetLinePath();
  }

  @override
  void endPath() {
    resetLinePath();
  }

  @override
  void clipPath(PathWindingRule rule) {
    // PDF spec: clipping uses the current path and implicitly closes subpaths.
    // The resulting clip region is part of the graphics state.
    final devicePath = _buildDeviceClipPathForCurrentPath();
    if (devicePath == null) {
      _setFillRule(rule);
      return;
    }

    _clipEntries.add(_ClipEntry(devicePath, rule));
    _invalidateClipMask();

    // Preserve call order compatibility (some backends rely on fill rule state).
    _setFillRule(rule);
  }

  @override
  void clipToRect(PDRectangle rect) {
    // Build a path for the bounding box and clip to it
    moveTo(rect.lowerLeftX, rect.lowerLeftY);
    lineTo(rect.lowerLeftX + rect.width, rect.lowerLeftY);
    lineTo(rect.lowerLeftX + rect.width, rect.lowerLeftY + rect.height);
    lineTo(rect.lowerLeftX, rect.lowerLeftY + rect.height);
    closePath();
    clipPath(PathWindingRule.nonZero);
    endPath();
  }

  @override
  void processImageXObject(COSName name, PDImageXObject image) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final decoded = _decodeImage(image);
    if (decoded == null) {
      _log.fine('Unable to decode image XObject ${name.name}');
      return;
    }

    // PDFBox draws images in a unit square in user space. The CTM maps the
    // unit square into place. We also flip the image vertically to match PDF's
    // image coordinate system.
    _drawWithClip((_, __) {
      _syncTransform();
      _graphics.masterAlpha = state.nonStrokingAlphaConstant.clamp(0.0, 1.0);
      _graphics.drawImage(decoded, 0, 1, 1, -1);
    });
  }

  @override
  void processFormXObject(PDFormXObject form) {
    final formResources = form.resources ?? currentResources;
    if (formResources == null) {
      _log.warning('Form XObject without resources ignored');
      return;
    }
    form.resourceCache ??= _parameters.getPage().resourceCache;

    final group = form.group;
    final isIsolated = group?.isIsolated() ?? false;

    if (!isIsolated &&
        _graphics is BasicGraphics2D &&
        (_graphics as BasicGraphics2D).destImage is ImageBuffer) {
      final basicG = _graphics as BasicGraphics2D;
      final target = basicG.destImage as ImageBuffer;

      // Create a copy of the backdrop
      final backdrop = ImageBuffer(target.width, target.height);
      backdrop.copyFrom(target);

      final groupGraphics = GroupGraphics(target, basicG);
      _graphics = groupGraphics;

      try {
        _renderFormXObject(form, formResources);
      } finally {
        _graphics = basicG;
      }

      // Remove backdrop (Standard PDF equation for non-isolated groups)
      groupGraphics.removeBackdrop(backdrop, 0, 0);
      return;
    }

    if (isIsolated) {
      _drawWithClip((_, __) {
        _renderFormXObject(form, formResources);
      });
      return;
    }

    _renderFormXObject(form, formResources);
  }

  void _renderFormXObject(PDFormXObject form, PDResources formResources) {
    // In PDFBox, drawing a form behaves like an implicit q/Q around the form.
    pushGraphicsState();
    try {
      final m = form.matrix;
      concatenateMatrix(
        m.scaleX,
        m.shearY,
        m.shearX,
        m.scaleY,
        m.translateX,
        m.translateY,
      );

      final bbox = form.boundingBox;
      if (bbox != null) {
        appendRectangle(
            bbox.lowerLeftX, bbox.lowerLeftY, bbox.width, bbox.height);
        clipPath(PathWindingRule.nonZero);
        endPath();
      }

      processContentStream(form, formResources);
    } finally {
      popGraphicsState();
    }
  }

  @override
  void processShading(PDShading shading) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    _drawWithClip((_, __) {
      final state = currentGraphicsState;
      if (state == null) {
        return;
      }

      final w = _graphics.width;
      final h = _graphics.height;
      if (w <= 0 || h <= 0) {
        return;
      }

      final shadingToDevice = _cloneAffine(_graphics.transform);

      ImageBuffer? shadingBuffer;
      if (shading is PDShadingType1) {
        shadingBuffer = _renderFunctionShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType2) {
        shadingBuffer = _renderAxialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType3) {
        shadingBuffer = _renderRadialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDTriangleBasedShadingType) {
        // Type 4 and Type 5 (triangle mesh shadings)
        shadingBuffer = _renderTriangleMeshShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else {
        _log.fine('Unsupported shading type: ${shading.shadingType}');
        return;
      }
      if (shadingBuffer == null) {
        return;
      }

      final oldAlpha = _graphics.masterAlpha;
      _graphics.masterAlpha = state.nonStrokingAlphaConstant.clamp(0.0, 1.0);
      final oldTransform = _cloneAffine(_graphics.transform);
      _graphics.setTransform(Affine.identity());
      _graphics.drawImage(
        shadingBuffer,
        0,
        0,
        w.toDouble(),
        h.toDouble(),
      );
      _graphics.setTransform(oldTransform);
      _graphics.masterAlpha = oldAlpha;
    });
  }

  /// Renders a Type 1 (function-based) shading.
  /// Port of PDFBox Type1ShadingContext.
  ImageBuffer? _renderFunctionShading(
    PDShadingType1 shading, {
    required int width,
    required int height,
    required Affine shadingToDevice,
  }) {
    final cs = shading.colorSpace;
    if (cs == null) {
      return null;
    }

    // Domain: [xmin xmax ymin ymax], default [0 1 0 1]
    final domain = shading.domainValues;
    final xmin = domain[0];
    final xmax = domain[1];
    final ymin = domain[2];
    final ymax = domain[3];

    // Background color (optional)
    int? rgbBackground;
    final bg = shading.background;
    if (bg != null && bg.isNotEmpty) {
      final components = <double>[];
      for (var i = 0; i < bg.length; i++) {
        components.add(bg.getDouble(i) ?? 0.0);
      }
      final rgb = cs.toRGB(cs.normalizeComponents(components));
      rgbBackground = _rgbToInt(rgb);
    }

    // Compute BBox restriction if present
    _IntRect? bboxDevice;
    final bbox = shading.bbox;
    if (bbox != null) {
      final xA = bbox.lowerLeftX;
      final yA = bbox.lowerLeftY;
      final xB = bbox.upperRightX;
      final yB = bbox.upperRightY;
      final t = shadingToDevice;
      final p00 = t.transformPoint(xA, yA);
      final p10 = t.transformPoint(xB, yA);
      final p01 = t.transformPoint(xA, yB);
      final p11 = t.transformPoint(xB, yB);
      final minX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.min);
      final maxX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.max);
      final minY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.min);
      final maxY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.max);
      final left = minX.floor().clamp(0, width);
      final right = maxX.ceil().clamp(0, width);
      final top = minY.floor().clamp(0, height);
      final bottom = maxY.ceil().clamp(0, height);
      if (right > left && bottom > top) {
        bboxDevice = _IntRect(left, top, right, bottom);
      }
    }

    // Build the inverse transform:
    // device -> shading space (shadingToDevice^-1) -> shading matrix^-1
    // This gives us coordinates in the domain space for function evaluation.
    final shadingMatrix = shading.matrix;
    final shadingMatrixAffine = Affine(
      shadingMatrix.scaleX,
      shadingMatrix.shearY,
      shadingMatrix.shearX,
      shadingMatrix.scaleY,
      shadingMatrix.translateX,
      shadingMatrix.translateY,
    );

    // Compute inverse transforms
    final deviceToShading = _invertAffine(shadingToDevice);
    final shadingToFunction = _invertAffine(shadingMatrixAffine);

    // Combined: device -> shading -> function domain
    final deviceToFunction = Affine.identity();
    deviceToFunction.multiply(shadingToFunction);
    deviceToFunction.multiply(deviceToShading);

    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (bboxDevice != null &&
            (x < bboxDevice.left ||
                x >= bboxDevice.right ||
                y < bboxDevice.top ||
                y >= bboxDevice.bottom)) {
          continue;
        }

        // Transform pixel center to function domain space
        final p = deviceToFunction.transformPoint(x + 0.5, y + 0.5);
        final fx = p.x;
        final fy = p.y;

        final o = (y * width + x) * 4;

        // Check if point is within domain
        if (fx < xmin || fx > xmax || fy < ymin || fy > ymax) {
          // Outside domain - use background if available
          if (rgbBackground != null) {
            buf[o] = (rgbBackground >> 16) & 0xFF;
            buf[o + 1] = (rgbBackground >> 8) & 0xFF;
            buf[o + 2] = rgbBackground & 0xFF;
            buf[o + 3] = 255;
          }
          continue;
        }

        // Evaluate function at (fx, fy)
        final values = shading.evalFunction(<double>[fx, fy]);
        if (values == null) {
          continue;
        }

        // Convert to RGB
        final rgb = cs.toRGB(cs.normalizeComponents(values));
        final rgbInt = _rgbToInt(rgb);

        buf[o] = (rgbInt >> 16) & 0xFF;
        buf[o + 1] = (rgbInt >> 8) & 0xFF;
        buf[o + 2] = rgbInt & 0xFF;
        buf[o + 3] = 255;
      }
    }

    return out;
  }

  /// Renders a Type 4/5 (Gouraud-shaded triangle mesh) shading.
  /// Port of PDFBox TriangleBasedShadingContext.
  ImageBuffer? _renderTriangleMeshShading(
    PDTriangleBasedShadingType shading, {
    required int width,
    required int height,
    required Affine shadingToDevice,
  }) {
    final cs = shading.colorSpace;
    if (cs == null) {
      return null;
    }

    // Background color (optional)
    int? rgbBackground;
    final bg = shading.background;
    if (bg != null && bg.isNotEmpty) {
      final components = <double>[];
      for (var i = 0; i < bg.length; i++) {
        components.add(bg.getDouble(i) ?? 0.0);
      }
      final rgb = cs.toRGB(cs.normalizeComponents(components));
      rgbBackground = _rgbToInt(rgb);
    }

    // Get the current transform matrix
    final state = currentGraphicsState;
    if (state == null) {
      return null;
    }

    // Collect triangles - pass transform and matrix
    final matrix = shading is PDShadingType1
        ? (shading as PDShadingType1).matrix
        : Matrix();
    List<ShadedTriangle> triangles;
    try {
      triangles = shading.collectTriangles(shadingToDevice, matrix);
    } catch (e) {
      _log.fine('Error collecting triangles: $e');
      return null;
    }

    if (triangles.isEmpty) {
      return null;
    }

    // Check for function to use for color transformation
    final fn = shading.cosObject.getDictionaryObject(COSName.function);
    final PDFunction? shadingFunction =
        fn != null ? PDFunction.create(fn) : null;

    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();

    // For each pixel, find the triangle it belongs to and calculate the color
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final o = (y * width + x) * 4;

        // Create a point for this pixel
        final pixel = Point(x + 0.5, y + 0.5);

        // Find which triangle contains this point
        ShadedTriangle? containingTriangle;
        for (final triangle in triangles) {
          if (triangle.contains(pixel)) {
            containingTriangle = triangle;
            break;
          }
        }

        if (containingTriangle == null) {
          // Not inside any triangle - use background if available
          if (rgbBackground != null) {
            buf[o] = (rgbBackground >> 16) & 0xFF;
            buf[o + 1] = (rgbBackground >> 8) & 0xFF;
            buf[o + 2] = rgbBackground & 0xFF;
            buf[o + 3] = 255;
          }
          continue;
        }

        // Calculate the color for this point using barycentric interpolation
        var colorValues = containingTriangle.calcColor(pixel);

        // Apply function if present
        if (shadingFunction != null) {
          colorValues = shadingFunction.eval(colorValues);
        }

        // Convert to RGB
        final rgb = cs.toRGB(cs.normalizeComponents(colorValues));
        final rgbInt = _rgbToInt(rgb);

        buf[o] = (rgbInt >> 16) & 0xFF;
        buf[o + 1] = (rgbInt >> 8) & 0xFF;
        buf[o + 2] = rgbInt & 0xFF;
        buf[o + 3] = 255;
      }
    }

    return out;
  }

  ImageBuffer? _renderAxialShading(
    PDShadingType2 shading, {
    required int width,
    required int height,
    required Affine shadingToDevice,
  }) {
    final cs = shading.colorSpace;
    final coordsArray = shading.coords;
    if (cs == null || coordsArray == null || coordsArray.length < 4) {
      return null;
    }

    final function = shading.function;
    if (function == null) {
      return null;
    }

    final x0 = coordsArray.getDouble(0) ?? 0.0;
    final y0 = coordsArray.getDouble(1) ?? 0.0;
    final x1 = coordsArray.getDouble(2) ?? 0.0;
    final y1 = coordsArray.getDouble(3) ?? 0.0;

    final domainArray = shading.domain;
    final d0 = (domainArray?.getDouble(0) ?? 0.0);
    final d1 = (domainArray?.getDouble(1) ?? 1.0);
    final d1d0 = d1 - d0;

    var extend0 = false;
    var extend1 = false;
    final extendArray = shading.extend;
    if (extendArray != null && extendArray.length >= 2) {
      final e0 = extendArray.getObject(0);
      final e1 = extendArray.getObject(1);
      extend0 = (e0 is COSBoolean && e0.value);
      extend1 = (e1 is COSBoolean && e1.value);
    }

    int? rgbBackground;
    final bg = shading.background;
    if (bg != null && bg.isNotEmpty) {
      final components = <double>[];
      for (var i = 0; i < bg.length; i++) {
        components.add(bg.getDouble(i) ?? 0.0);
      }
      final rgb = cs.toRGB(cs.normalizeComponents(components));
      final r = (rgb.isNotEmpty ? rgb[0] : 0.0).clamp(0.0, 1.0);
      final g = (rgb.length > 1 ? rgb[1] : 0.0).clamp(0.0, 1.0);
      final b = (rgb.length > 2 ? rgb[2] : 0.0).clamp(0.0, 1.0);
      rgbBackground = ((r * 255).round().clamp(0, 255) << 16) |
          ((g * 255).round().clamp(0, 255) << 8) |
          (b * 255).round().clamp(0, 255);
    }

    // Compute bounds for optional BBox restriction.
    _IntRect? bboxDevice;
    final bbox = shading.bbox;
    if (bbox != null) {
      final xA = bbox.lowerLeftX;
      final yA = bbox.lowerLeftY;
      final xB = bbox.upperRightX;
      final yB = bbox.upperRightY;
      final t = shadingToDevice;
      final p00 = t.transformPoint(xA, yA);
      final p10 = t.transformPoint(xB, yA);
      final p01 = t.transformPoint(xA, yB);
      final p11 = t.transformPoint(xB, yB);
      final minX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.min);
      final maxX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.max);
      final minY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.min);
      final maxY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.max);
      final left = minX.floor().clamp(0, width);
      final right = maxX.ceil().clamp(0, width);
      final top = minY.floor().clamp(0, height);
      final bottom = maxY.ceil().clamp(0, height);
      if (right > left && bottom > top) {
        bboxDevice = _IntRect(left, top, right, bottom);
      }
    }

    final dx = x1 - x0;
    final dy = y1 - y0;
    final denom = dx * dx + dy * dy;

    final dist = math.sqrt((width * width + height * height).toDouble());
    final factor = dist.isFinite ? dist.ceil().clamp(0, 8192) : 0;

    final colorTable = List<int>.filled(factor + 1, 0);
    if (factor == 0 || d1d0 == 0.0) {
      final values = shading.evalFunction(d0);
      if (values != null) {
        final rgb = cs.toRGB(cs.normalizeComponents(values));
        colorTable[0] = _rgbToInt(rgb);
      }
    } else {
      for (var i = 0; i <= factor; i++) {
        final t = d0 + d1d0 * i / factor;
        final values = shading.evalFunction(t);
        if (values == null) {
          continue;
        }
        final rgb = cs.toRGB(cs.normalizeComponents(values));
        colorTable[i] = _rgbToInt(rgb);
      }
    }

    final deviceToUser = _invertAffine(shadingToDevice);

    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (bboxDevice != null &&
            (x < bboxDevice.left ||
                x >= bboxDevice.right ||
                y < bboxDevice.top ||
                y >= bboxDevice.bottom)) {
          continue;
        }

        final p = deviceToUser.transformPoint(x + 0.5, y + 0.5);
        final nx = p.x - x0;
        final ny = p.y - y0;

        final o = (y * width + x) * 4;

        double u;
        if (denom == 0.0) {
          if (rgbBackground == null) {
            continue;
          }
          u = double.nan;
        } else {
          u = (dx * nx + dy * ny) / denom;
        }

        int rgb;
        if (!u.isFinite) {
          rgb = rgbBackground ?? 0;
        } else if (u < 0.0) {
          if (extend0) {
            rgb = colorTable.isNotEmpty ? colorTable[0] : 0;
          } else if (rgbBackground != null) {
            rgb = rgbBackground;
          } else {
            continue;
          }
        } else if (u > 1.0) {
          if (extend1) {
            rgb = colorTable.isNotEmpty ? colorTable[factor] : 0;
          } else if (rgbBackground != null) {
            rgb = rgbBackground;
          } else {
            continue;
          }
        } else {
          final key = (u * factor).floor().clamp(0, factor);
          rgb = colorTable[key];
        }

        buf[o] = (rgb >> 16) & 0xFF;
        buf[o + 1] = (rgb >> 8) & 0xFF;
        buf[o + 2] = rgb & 0xFF;
        buf[o + 3] = 255;
      }
    }

    return out;
  }

  ImageBuffer? _renderRadialShading(
    PDShadingType3 shading, {
    required int width,
    required int height,
    required Affine shadingToDevice,
  }) {
    final cs = shading.colorSpace;
    final coordsArray = shading.coords;
    if (cs == null || coordsArray == null || coordsArray.length < 6) {
      return null;
    }

    final x0 = coordsArray.getDouble(0) ?? 0.0;
    final y0 = coordsArray.getDouble(1) ?? 0.0;
    final r0 = coordsArray.getDouble(2) ?? 0.0;
    final x1 = coordsArray.getDouble(3) ?? 0.0;
    final y1 = coordsArray.getDouble(4) ?? 0.0;
    final r1 = coordsArray.getDouble(5) ?? 0.0;

    final domainArray = shading.domain;
    final d0 = (domainArray?.getDouble(0) ?? 0.0);
    final d1 = (domainArray?.getDouble(1) ?? 1.0);
    final d1d0 = d1 - d0;

    var extend0 = false;
    var extend1 = false;
    final extendArray = shading.extend;
    if (extendArray != null && extendArray.length >= 2) {
      final e0 = extendArray.getObject(0);
      final e1 = extendArray.getObject(1);
      extend0 = (e0 is COSBoolean && e0.value);
      extend1 = (e1 is COSBoolean && e1.value);
    }

    int? rgbBackground;
    final bg = shading.background;
    if (bg != null && bg.isNotEmpty) {
      final components = <double>[];
      for (var i = 0; i < bg.length; i++) {
        components.add(bg.getDouble(i) ?? 0.0);
      }
      final rgb = cs.toRGB(cs.normalizeComponents(components));
      rgbBackground = _rgbToInt(rgb);
    }

    _IntRect? bboxDevice;
    final bbox = shading.bbox;
    if (bbox != null) {
      final xA = bbox.lowerLeftX;
      final yA = bbox.lowerLeftY;
      final xB = bbox.upperRightX;
      final yB = bbox.upperRightY;
      final t = shadingToDevice;
      final p00 = t.transformPoint(xA, yA);
      final p10 = t.transformPoint(xB, yA);
      final p01 = t.transformPoint(xA, yB);
      final p11 = t.transformPoint(xB, yB);
      final minX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.min);
      final maxX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.max);
      final minY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.min);
      final maxY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.max);
      final left = minX.floor().clamp(0, width);
      final right = maxX.ceil().clamp(0, width);
      final top = minY.floor().clamp(0, height);
      final bottom = maxY.ceil().clamp(0, height);
      if (right > left && bottom > top) {
        bboxDevice = _IntRect(left, top, right, bottom);
      }
    }

    final x1x0 = x1 - x0;
    final y1y0 = y1 - y0;
    final r1r0 = r1 - r0;
    final r0pow2 = r0 * r0;
    final denom = x1x0 * x1x0 + y1y0 * y1y0 - r1r0 * r1r0;

    final dist = math.sqrt((width * width + height * height).toDouble());
    final factor = dist.isFinite ? dist.ceil().clamp(0, 8192) : 0;

    final colorTable = List<int>.filled(factor + 1, 0);
    if (factor == 0 || d1d0 == 0.0) {
      final values = shading.evalFunction(d0);
      if (values != null) {
        final rgb = cs.toRGB(cs.normalizeComponents(values));
        colorTable[0] = _rgbToInt(rgb);
      }
    } else {
      for (var i = 0; i <= factor; i++) {
        final t = d0 + d1d0 * i / factor;
        final values = shading.evalFunction(t);
        if (values == null) {
          continue;
        }
        final rgb = cs.toRGB(cs.normalizeComponents(values));
        colorTable[i] = _rgbToInt(rgb);
      }
    }

    final deviceToShading = _invertAffine(shadingToDevice);
    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (bboxDevice != null &&
            (x < bboxDevice.left ||
                x >= bboxDevice.right ||
                y < bboxDevice.top ||
                y >= bboxDevice.bottom)) {
          continue;
        }

        final p = deviceToShading.transformPoint(x + 0.5, y + 0.5);
        final px = p.x;
        final py = p.y;

        final o = (y * width + x) * 4;

        // Port of PDFBox RadialShadingContext.calculateInputValues()
        // p = -(x - x0) * (x1-x0) - (y - y0) * (y1-y0) - r0 * (r1-r0)
        final dx0 = px - x0;
        final dy0 = py - y0;
        final pVal = -(dx0) * x1x0 - (dy0) * y1y0 - r0 * r1r0;
        final qVal = (dx0 * dx0 + dy0 * dy0 - r0pow2);

        if (denom == 0.0) {
          if (rgbBackground == null) {
            continue;
          }
          final rgb = rgbBackground;
          buf[o] = (rgb >> 16) & 0xFF;
          buf[o + 1] = (rgb >> 8) & 0xFF;
          buf[o + 2] = rgb & 0xFF;
          buf[o + 3] = 255;
          continue;
        }

        final disc = pVal * pVal - denom * qVal;
        if (disc < 0 || !disc.isFinite) {
          if (rgbBackground == null) {
            continue;
          }
          final rgb = rgbBackground;
          buf[o] = (rgb >> 16) & 0xFF;
          buf[o + 1] = (rgb >> 8) & 0xFF;
          buf[o + 2] = rgb & 0xFF;
          buf[o + 3] = 255;
          continue;
        }

        final root = math.sqrt(disc);
        var root1 = (-pVal + root) / denom;
        var root2 = (-pVal - root) / denom;
        // Match PDFBox ordering depending on denom sign.
        if (denom >= 0) {
          final tmp = root1;
          root1 = root2;
          root2 = tmp;
        }

        double inputValue;
        final in1 = root1 >= 0 && root1 <= 1;
        final in2 = root2 >= 0 && root2 <= 1;
        var useBackground = false;
        if (in1) {
          inputValue = in2 ? math.max(root1, root2) : root1;
        } else if (in2) {
          inputValue = root2;
        } else {
          if (extend0 && extend1) {
            inputValue = math.max(root1, root2);
          } else if (extend0) {
            inputValue = root1;
          } else if (extend1) {
            inputValue = root2;
          } else if (rgbBackground != null) {
            useBackground = true;
            inputValue = 0;
          } else {
            continue;
          }
        }

        if (!useBackground) {
          if (inputValue > 1) {
            if (extend1 && r1 > 0) {
              inputValue = 1;
            } else if (rgbBackground != null) {
              useBackground = true;
            } else {
              continue;
            }
          } else if (inputValue < 0) {
            if (extend0 && r0 > 0) {
              inputValue = 0;
            } else if (rgbBackground != null) {
              useBackground = true;
            } else {
              continue;
            }
          }
        }

        final rgb = useBackground
            ? (rgbBackground ?? 0)
            : colorTable[(inputValue * factor).floor().clamp(0, factor)];

        buf[o] = (rgb >> 16) & 0xFF;
        buf[o + 1] = (rgb >> 8) & 0xFF;
        buf[o + 2] = rgb & 0xFF;
        buf[o + 3] = 255;
      }
    }

    return out;
  }

  int _rgbToInt(List<double> rgb) {
    final r = (rgb.isNotEmpty ? rgb[0] : 0.0).clamp(0.0, 1.0);
    final g = (rgb.length > 1 ? rgb[1] : 0.0).clamp(0.0, 1.0);
    final b = (rgb.length > 2 ? rgb[2] : 0.0).clamp(0.0, 1.0);
    return ((r * 255).round().clamp(0, 255) << 16) |
        ((g * 255).round().clamp(0, 255) << 8) |
        (b * 255).round().clamp(0, 255);
  }

  Affine _invertAffine(Affine src) {
    final det = src.sx * src.sy - src.shx * src.shy;
    if (det == 0.0 || !det.isFinite) {
      return Affine.identity();
    }
    final invDet = 1.0 / det;
    final sx = src.sy * invDet;
    final shx = -src.shx * invDet;
    final shy = -src.shy * invDet;
    final sy = src.sx * invDet;
    final tx = (src.shx * src.ty - src.sy * src.tx) * invDet;
    final ty = (src.shy * src.tx - src.sx * src.ty) * invDet;
    return Affine(sx, shy, shx, sy, tx, ty);
  }

  @override
  void showTextString(COSString text) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final textState = state.textState;
    final font = textState.font;
    if (font == null) {
      _log.fine('No font for showTextString');
      return;
    }


    final fontSize = textState.fontSize;
    if (fontSize == 0) {
      return;
    }

    // Important: if we're already in a clipping mode (W/W*), drawing might be
    // routed through an offscreen buffer with an adjusted base transform. For
    // text clipping modes (Tr=4..7) we must compute clip geometry in the final
    // device space, so we capture the base transform before any offscreen draw.
    final baseForTextClip = _cloneAffine(_xform);

    final clipUnion = textState.renderingMode.isClip ? VertexStorage() : null;

    _drawWithClip((_, __) {
      _showTextBytes(
        text.bytes,
        font: font,
        clipUnion: clipUnion,
        clipBase: baseForTextClip,
      );
    });

    if (clipUnion != null && clipUnion.vertices().isNotEmpty) {
      _clipEntries.add(_ClipEntry(clipUnion, PathWindingRule.nonZero));
      _invalidateClipMask();
    }
  }

  @override
  void showTextStrings(COSArray array) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final textState = state.textState;
    final font = textState.font;
    if (font == null) {
      _log.fine('No font for showTextStrings');
      return;
    }

    // If we're in a text-clip mode we must apply the clip once for the whole
    // TJ array (union of glyph outlines), not once per COSString element.
    if (!textState.renderingMode.isClip) {
      super.showTextStrings(array);
      return;
    }

    final baseForTextClip = _cloneAffine(_xform);
    final clipUnion = VertexStorage();

    _drawWithClip((_, __) {
      for (final element in array) {
        if (element is COSString) {
          _showTextBytes(
            element.bytes,
            font: font,
            clipUnion: clipUnion,
            clipBase: baseForTextClip,
          );
        } else if (element is COSNumber) {
          applyTextAdjustment(element.doubleValue);
        }
      }
    });

    if (clipUnion.vertices().isNotEmpty) {
      _clipEntries.add(_ClipEntry(clipUnion, PathWindingRule.nonZero));
      _invalidateClipMask();
    }
  }

  void _drawWithClip(void Function(int dx, int dy) draw) {
    final state = currentGraphicsState;
    final softMask = state?.softMask;
    final hasClip = _clipEntries.isNotEmpty;
    final blendMode = state?.blendMode ?? pdf_blend.BlendMode.normal;

    if (!hasClip && softMask == null) {
      draw(0, 0);
      return;
    }

    final originalGraphics = _graphics;
    final originalBase = _xform;
    final fullW = originalGraphics.width;
    final fullH = originalGraphics.height;
    if (fullW <= 0 || fullH <= 0) {
      return;
    }

    _IntRect bounds;
    ImageBuffer? clipMask;
    if (hasClip) {
      _ensureClipMask();
      clipMask = _clipMask;
      final clipBounds = _clipBounds;
      if (clipMask == null || clipBounds == null || clipBounds.isEmpty) {
        return;
      }
      bounds = clipBounds;
    } else {
      bounds = _IntRect(0, 0, fullW, fullH);
    }

    final dx = bounds.left;
    final dy = bounds.top;

    final width = bounds.width;
    final height = bounds.height;
    if (width <= 0 || height <= 0) {
      return;
    }

    final temp = ImageBuffer(width, height);
    final tempG = temp.newGraphics2D();
    tempG.clear(Color(0, 0, 0, 0));

    final adjustedBase = _cloneAffine(originalBase)
      ..tx -= bounds.left.toDouble()
      ..ty -= bounds.top.toDouble();

    try {
      _graphics = tempG;
      _xform = adjustedBase;
      _syncTransform();
      draw(dx, dy);
    } finally {
      _graphics = originalGraphics;
      _xform = originalBase;
      _syncTransform();
    }

    if (clipMask != null) {
      _applyMaskSubset(temp, clipMask, bounds.left, bounds.top);
    }

    if (softMask != null) {
      final maskImage = _ensureSoftMaskMask(softMask, base: originalBase);
      if (maskImage != null) {
        final subtypeName = softMask.subtype?.name;
        final isLuminosity = subtypeName == 'Luminosity';

        final transfer = softMask.transferFunction;
        final bboxDevice = identical(_softMaskCacheKey, softMask)
            ? _softMaskCacheBBoxDevice
            : null;

        // Convert COSArray backdropColor to gray value for luminosity mode
        int? backdropGray;
        final bcArray = softMask.backdropColor;
        if (isLuminosity && bcArray != null && bcArray.isNotEmpty) {
          // For luminosity soft mask, compute gray from backdrop color
          // Using simple average or first component as approximation
          double sum = 0;
          for (var i = 0; i < bcArray.length; i++) {
            sum += bcArray.getDouble(i) ?? 0.0;
          }
          // Normalize to 0-255 assuming components are 0-1
          final avg = bcArray.length > 0 ? sum / bcArray.length : 0;
          backdropGray = (avg * 255).round().clamp(0, 255);
        }

        // Use SoftMask helper class
        final sm = SoftMask(
          maskImage,
          bboxDevice: bboxDevice == null
              ? null
              : RectangleInt(bboxDevice.left, bboxDevice.bottom,
                  bboxDevice.right, bboxDevice.top),
          backdropGray: backdropGray,
          transferFunction: transfer,
        );
        sm.apply(temp, bounds.left, bounds.top, luminosity: isLuminosity);
      }
    }

    if (originalGraphics is BasicGraphics2D &&
        originalGraphics.destImage is ImageBuffer) {
      if (blendMode != pdf_blend.BlendMode.normal) {
        _compositeBlendLayer(
          temp,
          originalGraphics,
          bounds,
          blendMode,
        );
      } else {
        _compositePremultipliedLayer(
          temp,
          originalGraphics.destImage as ImageBuffer,
          bounds,
        );
      }
    } else {
      originalGraphics.save();
      final originalAlpha = originalGraphics.masterAlpha;
      originalGraphics.masterAlpha = 1.0;
      originalGraphics.setTransform(Affine.identity());
      originalGraphics.drawImage(
        temp,
        bounds.left.toDouble(),
        bounds.top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      );
      originalGraphics.masterAlpha = originalAlpha;
      originalGraphics.restore();
    }
  }

  void _compositeBlendLayer(
    ImageBuffer layer,
    BasicGraphics2D target,
    _IntRect bounds,
    pdf_blend.BlendMode mode,
  ) {
    final dst = target.destImage;
    if (dst is! ImageBuffer) {
      target.save();
      final originalAlpha = target.masterAlpha;
      target.masterAlpha = 1.0;
      target.setTransform(Affine.identity());
      target.drawImage(
        layer,
        bounds.left.toDouble(),
        bounds.top.toDouble(),
        bounds.width.toDouble(),
        bounds.height.toDouble(),
      );
      target.masterAlpha = originalAlpha;
      target.restore();
      return;
    }

    final srcBytes = layer.getBuffer();
    final dstBytes = dst.getBuffer();

    final dstW = dst.width;
    final srcW = layer.width;
    final srcH = layer.height;

    final left = bounds.left;
    final top = bounds.top;

    for (var y = 0; y < srcH; y++) {
      final dstRow = (top + y) * dstW;
      final srcRow = y * srcW;
      for (var x = 0; x < srcW; x++) {
        final si = (srcRow + x) * 4;
        final di = (dstRow + left + x) * 4;

        final sr = srcBytes[si];
        final sg = srcBytes[si + 1];
        final sb = srcBytes[si + 2];
        final sa = srcBytes[si + 3];
        if (sa == 0) continue;

        final dr = dstBytes[di];
        final dg = dstBytes[di + 1];
        final db = dstBytes[di + 2];
        final da = dstBytes[di + 3];

        final out = _blendPixel(
          sr,
          sg,
          sb,
          sa,
          dr,
          dg,
          db,
          da,
          _mapBlendMode(mode),
        );

        dstBytes[di] = out.$1;
        dstBytes[di + 1] = out.$2;
        dstBytes[di + 2] = out.$3;
        dstBytes[di + 3] = out.$4;
      }
    }
  }

  void _compositePremultipliedLayer(
    ImageBuffer layer,
    ImageBuffer target,
    _IntRect bounds,
  ) {
    final srcBytes = layer.getBuffer();
    final dstBytes = target.getBuffer();

    final dstW = target.width;
    final srcW = layer.width;
    final srcH = layer.height;

    final left = bounds.left;
    final top = bounds.top;

    for (var y = 0; y < srcH; y++) {
      final dstRow = (top + y) * dstW;
      final srcRow = y * srcW;
      for (var x = 0; x < srcW; x++) {
        final si = (srcRow + x) * 4;
        final di = (dstRow + left + x) * 4;

        final sa = srcBytes[si + 3];
        if (sa == 0) {
          continue;
        }
        if (sa == 255) {
          dstBytes[di] = srcBytes[si];
          dstBytes[di + 1] = srcBytes[si + 1];
          dstBytes[di + 2] = srcBytes[si + 2];
          dstBytes[di + 3] = 255;
          continue;
        }

        final invA = 255 - sa;
        dstBytes[di] =
            srcBytes[si] + ((dstBytes[di] * invA) ~/ 255);
        dstBytes[di + 1] =
            srcBytes[si + 1] + ((dstBytes[di + 1] * invA) ~/ 255);
        dstBytes[di + 2] =
            srcBytes[si + 2] + ((dstBytes[di + 2] * invA) ~/ 255);
        dstBytes[di + 3] =
            sa + ((dstBytes[di + 3] * invA) ~/ 255);
      }
    }
  }

  _BlendModeLite _mapBlendMode(pdf_blend.BlendMode mode) {
    switch (mode) {
      case pdf_blend.BlendMode.multiply:
        return _BlendModeLite.multiply;
      case pdf_blend.BlendMode.screen:
        return _BlendModeLite.screen;
      case pdf_blend.BlendMode.overlay:
        return _BlendModeLite.overlay;
      case pdf_blend.BlendMode.darken:
        return _BlendModeLite.darken;
      case pdf_blend.BlendMode.lighten:
        return _BlendModeLite.lighten;
      case pdf_blend.BlendMode.colorDodge:
        return _BlendModeLite.colorDodge;
      case pdf_blend.BlendMode.colorBurn:
        return _BlendModeLite.colorBurn;
      case pdf_blend.BlendMode.hardLight:
        return _BlendModeLite.hardLight;
      case pdf_blend.BlendMode.softLight:
        return _BlendModeLite.softLight;
      case pdf_blend.BlendMode.difference:
        return _BlendModeLite.difference;
      case pdf_blend.BlendMode.exclusion:
        return _BlendModeLite.exclusion;
      case pdf_blend.BlendMode.normal:
      case pdf_blend.BlendMode.hue:
      case pdf_blend.BlendMode.saturation:
      case pdf_blend.BlendMode.color:
      case pdf_blend.BlendMode.luminosity:
        return _BlendModeLite.srcOver;
    }
  }

  (int, int, int, int) _blendPixel(
    int sr,
    int sg,
    int sb,
    int sa,
    int dr,
    int dg,
    int db,
    int da,
    _BlendModeLite mode,
  ) {
    final as = sa / 255.0;
    final ad = da / 255.0;
    final cs = sr / 255.0;
    final csG = sg / 255.0;
    final csB = sb / 255.0;
    final cd = dr / 255.0;
    final cdG = dg / 255.0;
    final cdB = db / 255.0;

    switch (mode) {
      case _BlendModeLite.clear:
        return (0, 0, 0, 0);
      case _BlendModeLite.dst:
        return (dr, dg, db, da);
      case _BlendModeLite.src:
        return (sr, sg, sb, sa);
      case _BlendModeLite.srcOver:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.srcOver);
      case _BlendModeLite.dstOver:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.dstOver);
      case _BlendModeLite.srcIn:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.srcIn);
      case _BlendModeLite.dstIn:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.dstIn);
      case _BlendModeLite.srcOut:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.srcOut);
      case _BlendModeLite.dstOut:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.dstOut);
      case _BlendModeLite.srcAtop:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.srcAtop);
      case _BlendModeLite.dstAtop:
        return _porterDuff(
            cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.dstAtop);
      case _BlendModeLite.xor:
        return _porterDuff(cs, csG, csB, as, cd, cdG, cdB, ad, _PorterDuff.xor);
      case _BlendModeLite.add:
        return _blendWithMode(cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.add);
      case _BlendModeLite.multiply:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.multiply);
      case _BlendModeLite.screen:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.screen);
      case _BlendModeLite.overlay:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.overlay);
      case _BlendModeLite.darken:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.darken);
      case _BlendModeLite.lighten:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.lighten);
      case _BlendModeLite.colorDodge:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.colorDodge);
      case _BlendModeLite.colorBurn:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.colorBurn);
      case _BlendModeLite.hardLight:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.hardLight);
      case _BlendModeLite.softLight:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.softLight);
      case _BlendModeLite.difference:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.difference);
      case _BlendModeLite.exclusion:
        return _blendWithMode(
            cs, csG, csB, as, cd, cdG, cdB, ad, _BlendFn.exclusion);
    }
  }

  (int, int, int, int) _porterDuff(
    double cs,
    double csG,
    double csB,
    double as,
    double cd,
    double cdG,
    double cdB,
    double ad,
    _PorterDuff mode,
  ) {
    double ps = cs * as;
    double psG = csG * as;
    double psB = csB * as;
    double pd = cd * ad;
    double pdG = cdG * ad;
    double pdB = cdB * ad;

    double po = 0;
    double poG = 0;
    double poB = 0;
    double ao = 0;

    switch (mode) {
      case _PorterDuff.clear:
        ao = 0;
        po = 0;
        poG = 0;
        poB = 0;
        break;
      case _PorterDuff.src:
        ao = as;
        po = ps;
        poG = psG;
        poB = psB;
        break;
      case _PorterDuff.dst:
        ao = ad;
        po = pd;
        poG = pdG;
        poB = pdB;
        break;
      case _PorterDuff.srcOver:
        ao = as + ad * (1 - as);
        po = ps + pd * (1 - as);
        poG = psG + pdG * (1 - as);
        poB = psB + pdB * (1 - as);
        break;
      case _PorterDuff.dstOver:
        ao = ad + as * (1 - ad);
        po = pd + ps * (1 - ad);
        poG = pdG + psG * (1 - ad);
        poB = pdB + psB * (1 - ad);
        break;
      case _PorterDuff.srcIn:
        ao = as * ad;
        po = ps * ad;
        poG = psG * ad;
        poB = psB * ad;
        break;
      case _PorterDuff.dstIn:
        ao = ad * as;
        po = pd * as;
        poG = pdG * as;
        poB = pdB * as;
        break;
      case _PorterDuff.srcOut:
        ao = as * (1 - ad);
        po = ps * (1 - ad);
        poG = psG * (1 - ad);
        poB = psB * (1 - ad);
        break;
      case _PorterDuff.dstOut:
        ao = ad * (1 - as);
        po = pd * (1 - as);
        poG = pdG * (1 - as);
        poB = pdB * (1 - as);
        break;
      case _PorterDuff.srcAtop:
        ao = ad;
        po = ps * ad + pd * (1 - as);
        poG = psG * ad + pdG * (1 - as);
        poB = psB * ad + pdB * (1 - as);
        break;
      case _PorterDuff.dstAtop:
        ao = as;
        po = pd * as + ps * (1 - ad);
        poG = pdG * as + psG * (1 - ad);
        poB = pdB * as + psB * (1 - ad);
        break;
      case _PorterDuff.xor:
        ao = as * (1 - ad) + ad * (1 - as);
        po = ps * (1 - ad) + pd * (1 - as);
        poG = psG * (1 - ad) + pdG * (1 - as);
        poB = psB * (1 - ad) + pdB * (1 - as);
        break;
    }

    if (ao <= 0) {
      return (0, 0, 0, 0);
    }

    final r = (po / ao * 255).round().clamp(0, 255);
    final g = (poG / ao * 255).round().clamp(0, 255);
    final b = (poB / ao * 255).round().clamp(0, 255);
    final a = (ao * 255).round().clamp(0, 255);
    return (r, g, b, a);
  }

  (int, int, int, int) _blendWithMode(
    double cs,
    double csG,
    double csB,
    double as,
    double cd,
    double cdG,
    double cdB,
    double ad,
    _BlendFn mode,
  ) {
    final ao = as + ad - as * ad;
    if (ao <= 0) {
      return (0, 0, 0, 0);
    }

    double blend(double s, double d) {
      switch (mode) {
        case _BlendFn.add:
          return math.min(1.0, s + d);
        case _BlendFn.multiply:
          return s * d;
        case _BlendFn.screen:
          return s + d - s * d;
        case _BlendFn.overlay:
          return d <= 0.5 ? 2 * s * d : 1 - 2 * (1 - s) * (1 - d);
        case _BlendFn.darken:
          return math.min(s, d);
        case _BlendFn.lighten:
          return math.max(s, d);
        case _BlendFn.colorDodge:
          if (s >= 1.0) return 1.0;
          return math.min(1.0, d / (1 - s));
        case _BlendFn.colorBurn:
          if (s <= 0.0) return 0.0;
          return 1 - math.min(1.0, (1 - d) / s);
        case _BlendFn.hardLight:
          return s <= 0.5 ? 2 * s * d : 1 - 2 * (1 - s) * (1 - d);
        case _BlendFn.softLight:
          if (s <= 0.5) {
            return d - (1 - 2 * s) * d * (1 - d);
          }
          double g;
          if (d <= 0.25) {
            g = ((16 * d - 12) * d + 4) * d;
          } else {
            g = math.sqrt(d);
          }
          return d + (2 * s - 1) * (g - d);
        case _BlendFn.difference:
          return (d - s).abs();
        case _BlendFn.exclusion:
          return s + d - 2 * s * d;
      }
    }

    final r = (255 * ((1 - as) * cd + (1 - ad) * cs + as * ad * blend(cs, cd)))
        .round()
        .clamp(0, 255);
    final g =
        (255 * ((1 - as) * cdG + (1 - ad) * csG + as * ad * blend(csG, cdG)))
            .round()
            .clamp(0, 255);
    final b =
        (255 * ((1 - as) * cdB + (1 - ad) * csB + as * ad * blend(csB, cdB)))
            .round()
            .clamp(0, 255);
    final a = (ao * 255).round().clamp(0, 255);
    return (r, g, b, a);
  }

  ImageBuffer? _ensureSoftMaskMask(PDSoftMask softMask,
      {required Affine base}) {
    final w = _graphics.width;
    final h = _graphics.height;
    if (w <= 0 || h <= 0) {
      return null;
    }

    if (identical(_softMaskCacheKey, softMask) &&
        _softMaskCacheMask != null &&
        _softMaskCacheMask!.width == w &&
        _softMaskCacheMask!.height == h) {
      return _softMaskCacheMask;
    }

    final groupStream = softMask.group;
    if (groupStream == null) {
      _softMaskCacheKey = softMask;
      _softMaskCacheMask = null;
      _softMaskCacheBBoxDevice = null;
      return null;
    }

    final form = PDFormXObject.fromCOSStream(groupStream);
    form.resourceCache ??= _parameters.getPage().resourceCache;

    _softMaskCacheBBoxDevice = _computeSoftMaskBBoxDevice(
      form,
      base: base,
      initial: softMask.getInitialTransformationMatrix(),
      w: w,
      h: h,
    );

    final mask = ImageBuffer(w, h);
    final maskG = mask.newGraphics2D();
    maskG.clear(Color(0, 0, 0, 0));

    final savedGraphics = _graphics;
    final savedBase = _xform;
    final savedClipEntries = List<_ClipEntry>.from(_clipEntries);
    final savedClipDepth = List<int>.from(_clipDepthStack);
    final savedClipVersion = _clipVersion;
    final savedClipMaskVersion = _clipMaskVersion;
    final savedClipMask = _clipMask;
    final savedClipBounds = _clipBounds;

    try {
      // Soft mask group is evaluated independent from the current clipping path.
      _clipEntries.clear();
      _clipDepthStack.clear();
      _clipVersion = 0;
      _clipMaskVersion = -1;
      _clipMask = null;
      _clipBounds = null;

      _graphics = maskG;
      _xform = _cloneAffine(base);
      _syncTransform();

      // Start the soft mask evaluation with the CTM active when gs was applied.
      final initial = softMask.getInitialTransformationMatrix();
      if (initial != null) {
        pushGraphicsState();
        try {
          final state = currentGraphicsState;
          if (state != null) {
            // Prevent the soft mask from being applied while computing itself.
            state.setSoftMask(null);
            state.currentTransformationMatrix = initial;
            _syncTransform();
          }
          processFormXObject(form);
        } finally {
          popGraphicsState();
        }
      } else {
        pushGraphicsState();
        try {
          final state = currentGraphicsState;
          if (state != null) {
            // Prevent the soft mask from being applied while computing itself.
            state.setSoftMask(null);
          }
          processFormXObject(form);
        } finally {
          popGraphicsState();
        }
      }
    } finally {
      _graphics = savedGraphics;
      _xform = savedBase;
      _clipEntries
        ..clear()
        ..addAll(savedClipEntries);
      _clipDepthStack
        ..clear()
        ..addAll(savedClipDepth);
      _clipVersion = savedClipVersion;
      _clipMaskVersion = savedClipMaskVersion;
      _clipMask = savedClipMask;
      _clipBounds = savedClipBounds;
      _syncTransform();
    }

    _softMaskCacheKey = softMask;
    _softMaskCacheMask = mask;
    return mask;
  }

  _IntRect? _computeSoftMaskBBoxDevice(
    PDFormXObject form, {
    required Affine base,
    required Matrix? initial,
    required int w,
    required int h,
  }) {
    final bbox = form.boundingBox;
    if (bbox == null) {
      return null;
    }

    // Build form->initial->base (base applied last to points).
    final combined = _matrixToAffine(form.matrix);
    if (initial != null) {
      combined.multiply(_matrixToAffine(initial));
    }
    combined.multiply(_cloneAffine(base));

    final x0 = bbox.lowerLeftX;
    final y0 = bbox.lowerLeftY;
    final x1 = bbox.upperRightX;
    final y1 = bbox.upperRightY;

    final p00 = combined.transformPoint(x0, y0);
    final p10 = combined.transformPoint(x1, y0);
    final p01 = combined.transformPoint(x0, y1);
    final p11 = combined.transformPoint(x1, y1);

    final minX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.min);
    final maxX = <double>[p00.x, p10.x, p01.x, p11.x].reduce(math.max);
    final minY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.min);
    final maxY = <double>[p00.y, p10.y, p01.y, p11.y].reduce(math.max);

    final left = minX.floor().clamp(0, w);
    final right = maxX.ceil().clamp(0, w);
    final top = minY.floor().clamp(0, h);
    final bottom = maxY.ceil().clamp(0, h);

    if (right <= left || bottom <= top) {
      return null;
    }

    return _IntRect(left, top, right, bottom);
  }

  bool _isPatternColor(PDColor color) {
    return color.patternName != null && color.colorSpace is PDPatternColorSpace;
  }

  void _fillCurrentPathWithPattern(PathWindingRule rule, PDColor patternColor) {
    final patternName = patternColor.patternName;
    if (patternName == null) {
      return;
    }

    final res = currentResources;
    if (res == null) {
      return;
    }

    final pattern = res.getPattern(patternName);

    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final w = _graphics.width;
    final h = _graphics.height;
    if (w <= 0 || h <= 0) {
      return;
    }

    // Build a mask from the current path.
    final mask = ImageBuffer(w, h);
    final mg = mask.newGraphics2D();
    mg.clear(Color(0, 0, 0, 0));
    mg.setTransform(_cloneAffine(_graphics.transform));
    mg.fillColor = Color(255, 255, 255, 255);
    mg.masterAlpha = 1.0;
    if (mg is BasicGraphics2D) {
      mg.rasterizer.fillingRule(
        rule == PathWindingRule.evenOdd
            ? FillingRuleE.fillEvenOdd
            : FillingRuleE.fillNonZero,
      );
    }
    mg.beginPath();
    mg.currentPath.concat(getLinePath());
    mg.fillPath();

    final ImageBuffer painted;
    if (pattern is PDTilingPattern) {
      // Render a tiled paint into a buffer.
      final paint = TilingPaintFactory().create(
        pattern: pattern,
        base: _cloneAffine(_xform),
        ctm: state.currentTransformationMatrix,
        drawCell: (p, g, base) => drawTilingPatternCell(p,
            graphics: g, base: base, patternColor: patternColor),
      );
      if (paint == null) {
        return;
      }
      final tiled = ImageBuffer(w, h);
      tiled.newGraphics2D().clear(Color(0, 0, 0, 0));
      paint.paintInto(tiled, 0, 0);
      painted = tiled;
    } else if (pattern is PDShadingPattern) {
      final shading = pattern.shading;
      if (shading == null) {
        return;
      }

      // pattern matrix first, then current graphics transform.
      final shadingToDevice = _matrixToAffine(pattern.matrix)
        ..multiply(_cloneAffine(_graphics.transform));

      ImageBuffer? shadingBuffer;
      if (shading is PDShadingType1) {
        shadingBuffer = _renderFunctionShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType2) {
        shadingBuffer = _renderAxialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType3) {
        shadingBuffer = _renderRadialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDTriangleBasedShadingType) {
        shadingBuffer = _renderTriangleMeshShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      }
      if (shadingBuffer == null) {
        return;
      }
      painted = shadingBuffer;
    } else {
      return;
    }

    // Apply the path mask.
    _applyMaskSubset(painted, mask, 0, 0);

    // Composite into the target.
    _graphics.save();
    final oldAlpha = _graphics.masterAlpha;
    _graphics.masterAlpha = state.nonStrokingAlphaConstant.clamp(0.0, 1.0);
    _graphics.setTransform(Affine.identity());
    _graphics.drawImage(painted, 0, 0, w.toDouble(), h.toDouble());
    _graphics.masterAlpha = oldAlpha;
    _graphics.restore();
  }

  void _strokeCurrentPathWithPattern(PDColor patternColor) {
    final patternName = patternColor.patternName;
    if (patternName == null) {
      return;
    }

    final res = currentResources;
    if (res == null) {
      return;
    }

    final pattern = res.getPattern(patternName);

    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final w = _graphics.width;
    final h = _graphics.height;
    if (w <= 0 || h <= 0) {
      return;
    }

    // Stroke mask from the current path.
    final mask = ImageBuffer(w, h);
    final mg = mask.newGraphics2D();
    mg.clear(Color(0, 0, 0, 0));
    mg.setTransform(_cloneAffine(_graphics.transform));
    mg.strokeColor = Color(255, 255, 255, 255);
    mg.masterAlpha = 1.0;
    mg.lineWidth = state.lineWidth;
    mg.lineCap = _mapLineCap(state.lineCap);
    mg.lineJoin = _mapLineJoin(state.lineJoin);
    mg.miterLimit = state.miterLimit;
    mg.beginPath();
    mg.currentPath.concat(getLinePath());
    mg.strokePath();

    final ImageBuffer painted;
    if (pattern is PDTilingPattern) {
      final paint = TilingPaintFactory().create(
        pattern: pattern,
        base: _cloneAffine(_xform),
        ctm: state.currentTransformationMatrix,
        drawCell: (p, g, base) => drawTilingPatternCell(p,
            graphics: g, base: base, patternColor: patternColor),
      );
      if (paint == null) {
        return;
      }
      final tiled = ImageBuffer(w, h);
      tiled.newGraphics2D().clear(Color(0, 0, 0, 0));
      paint.paintInto(tiled, 0, 0);
      painted = tiled;
    } else if (pattern is PDShadingPattern) {
      final shading = pattern.shading;
      if (shading == null) {
        return;
      }

      // pattern matrix first, then current graphics transform.
      final shadingToDevice = _matrixToAffine(pattern.matrix)
        ..multiply(_cloneAffine(_graphics.transform));

      ImageBuffer? shadingBuffer;
      if (shading is PDShadingType1) {
        shadingBuffer = _renderFunctionShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType2) {
        shadingBuffer = _renderAxialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDShadingType3) {
        shadingBuffer = _renderRadialShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      } else if (shading is PDTriangleBasedShadingType) {
        shadingBuffer = _renderTriangleMeshShading(
          shading,
          width: w,
          height: h,
          shadingToDevice: shadingToDevice,
        );
      }
      if (shadingBuffer == null) {
        return;
      }
      painted = shadingBuffer;
    } else {
      return;
    }

    _applyMaskSubset(painted, mask, 0, 0);

    _graphics.save();
    final oldAlpha = _graphics.masterAlpha;
    _graphics.masterAlpha = state.alphaConstant.clamp(0.0, 1.0);
    _graphics.setTransform(Affine.identity());
    _graphics.drawImage(painted, 0, 0, w.toDouble(), h.toDouble());
    _graphics.masterAlpha = oldAlpha;
    _graphics.restore();
  }

  /// Renders a tiling pattern cell into [graphics].
  ///
  /// This mirrors PDFBox's approach of running the pattern stream with its own
  /// resources and isolation from the current clipping path.
  void drawTilingPatternCell(
    PDTilingPattern pattern, {
    required Graphics2D graphics,
    required Affine base,
    required PDColor patternColor,
  }) {
    final savedGraphics = _graphics;
    final savedBase = _xform;
    final savedClipEntries = List<_ClipEntry>.from(_clipEntries);
    final savedClipDepth = List<int>.from(_clipDepthStack);
    final savedClipVersion = _clipVersion;
    final savedClipMaskVersion = _clipMaskVersion;
    final savedClipMask = _clipMask;
    final savedClipBounds = _clipBounds;
    final prevColorOps = shouldProcessColorOperators;

    try {
      _clipEntries.clear();
      _clipDepthStack.clear();
      _clipVersion = 0;
      _clipMaskVersion = -1;
      _clipMask = null;
      _clipBounds = null;

      _graphics = graphics;
      _xform = base;

      pushGraphicsState();
      try {
        final state = currentGraphicsState;
        if (state != null) {
          // Patterns should not inherit the active soft mask.
          state.setSoftMask(null);

          // Apply the pattern matrix in the CTM.
          state.currentTransformationMatrix = pattern.matrix;

          if (pattern.paintType == 2) {
            // Uncoloured patterns: use the supplied underlying colour.
            final cs = patternColor.colorSpace;
            if (cs is PDPatternColorSpace && cs.underlying != null) {
              state.nonStrokingColor =
                  PDColor(patternColor.components, cs.underlying!);
              state.strokingColor =
                  PDColor(patternColor.components, cs.underlying!);
            }
          }
        }

        setShouldProcessColorOperators(pattern.paintType == 1);

        final bbox = pattern.boundingBox;
        if (bbox != null) {
          appendRectangle(
              bbox.lowerLeftX, bbox.lowerLeftY, bbox.width, bbox.height);
          clipPath(PathWindingRule.nonZero);
          endPath();
        }

        final pr = pattern.patternResources ?? currentResources;
        if (pr != null) {
          processContentStream(pattern.contentStream, pr);
        }
      } finally {
        popGraphicsState();
      }
    } finally {
      setShouldProcessColorOperators(prevColorOps);
      _graphics = savedGraphics;
      _xform = savedBase;
      _clipEntries
        ..clear()
        ..addAll(savedClipEntries);
      _clipDepthStack
        ..clear()
        ..addAll(savedClipDepth);
      _clipVersion = savedClipVersion;
      _clipMaskVersion = savedClipMaskVersion;
      _clipMask = savedClipMask;
      _clipBounds = savedClipBounds;
      _syncTransform();
    }
  }

  int _readCode(PDFont font, RandomAccessReadBuffer buffer) {
    if (buffer.isEOF) {
      return -1;
    }
    if (font is PDType0Font) {
      return font.readCode(buffer);
    }
    return buffer.read();
  }

  void _drawGlyph({required int code, required PDFont font}) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final textState = state.textState;
    final mode = textState.renderingMode;

    if (!mode.isFill && !mode.isStroke) {
      return;
    }

    if (font is PDType3Font) {
      _drawType3Glyph(code: code, font: font);
      return;
    }
    final resolved = _resolveVectorFont(font);
    if (resolved == null) {
      return;
    } 
    final vectorFont = resolved.vectorFont;
    final renderFont = resolved.renderFont;
    if (!vectorFont.hasGlyph(code)) {
      return;
    }

    final cache =
        _glyphCaches.putIfAbsent(renderFont, () => GlyphCache(vectorFont));
    final outline = cache.getPathForCharacterCode(code);
    if (outline.vertices().isEmpty) {
      return;
    }

    final trm = _glyphRenderingMatrix(state: state);
    final glyphMatrix = renderFont.fontMatrix.multiply(trm);

    // dart_graphics Affine.multiply() applies the RHS last (this = this * other).
    // We want: combined = base * (FontMatrix * TRM).
    final combined = _matrixToAffine(glyphMatrix)..multiply(_xform);
    _graphics.setTransform(combined);

    _graphics.beginPath();
    _graphics.currentPath.concat(outline);

    // Match PDFBox order: fill then stroke.
    _setFillRule(PathWindingRule.nonZero);
    if (mode.isFill) {
      _syncPaintStateForFill();
      _graphics.fillPath();
    }
    if (mode.isStroke) {
      _syncPaintStateForStroke();
      _graphics.strokePath();
    }
  }

  /// Returns a vector-capable font for rendering, falling back to a
  /// PDFontFactory-created font when the current font isn't vector-based.
  VectorFontResolution? _resolveVectorFont(PDFont font) {
    if (font is PDVectorFont) {
      return VectorFontResolution(font as PDVectorFont, font);
    }

    final cached = _vectorFontFallbacks[font];
    if (cached is PDVectorFont) {
      return VectorFontResolution(cached as PDVectorFont, cached as PDFont);
    }

    try {
      final created = PDFontFactory.createFont(font.cosObject);
      if (created is PDVectorFont) {
        _vectorFontFallbacks[font] = created;
        return VectorFontResolution(created as PDVectorFont, created);
      }
    } catch (_) {
      // Ignore fallback errors.
    }
    return null;
  }

  void _drawType3Glyph({required int code, required PDType3Font font}) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }

    final charStream = font.getCharStream(code);
    if (charStream == null) {
      return;
    }

    // Render the glyph by executing its charproc content stream.
    final savedXform = _xform;
    final savedColorOps = shouldProcessColorOperators;

    pushGraphicsState();
    try {
      final state = currentGraphicsState;
      if (state == null) {
        return;
      }

      // Port of PDFBox's processType3Stream(): replace the CTM with the text
      // rendering matrix (text space -> device space), then pre-concatenate the
      // Type3 font's matrix (FontMatrix) for the charproc stream.
      // Compute the Type3 charproc CTM from the text rendering matrix.
      final textRenderingMatrix = _glyphRenderingMatrix(state: state);
      state.currentTransformationMatrix =
          font.fontMatrix.multiply(textRenderingMatrix);
      state.textMatrix = Matrix();
      state.textLineMatrix = Matrix();

      _xform = savedXform;
      _syncTransform();

      _processingType3CharProc = true;
      _type3CharProcWidthWx = null;
      _type3CharProcWidthWy = null;

      // Type3 glyphs use the font's resource dictionary (spec). Some files are
      // malformed and omit it, so fall back to the current resource stack.
      final type3Resources = font.resources ?? currentResources;
      if (type3Resources != null) {
        setShouldProcessColorOperators(true);
        processContentStream(PDStream(charStream), type3Resources);
      }
    } finally {
      _processingType3CharProc = false;
      setShouldProcessColorOperators(savedColorOps);
      _xform = savedXform;
      popGraphicsState();
    }
  }

  void _showTextBytes(
    Uint8List bytes, {
    required PDFont font,
    VertexStorage? clipUnion,
    required Affine clipBase,
  }) {
    final buffer = RandomAccessReadBuffer.fromBytes(bytes);
    try {
      while (!buffer.isClosed && !buffer.isEOF) {
        final code = _readCode(font, buffer);
        if (code == -1) {
          break;
        }

        if (clipUnion != null) {
          final deviceGlyph = _buildDevicePathForGlyph(
            code: code,
            font: font,
            base: clipBase,
          );
          if (deviceGlyph != null && deviceGlyph.vertices().isNotEmpty) {
            clipUnion.concat(deviceGlyph);
          }
        }

        _drawGlyph(code: code, font: font);
        _advanceTextPosition(code: code, font: font);
      }
    } finally {
      buffer.close();
      // Restore the graphics transform after any glyph-specific transforms.
      _syncTransform();
    }
  }

  VertexStorage? _buildDevicePathForGlyph({
    required int code,
    required PDFont font,
    required Affine base,
  }) {
    final state = currentGraphicsState;
    if (state == null) {
      return null;
    }
    final resolved = _resolveVectorFont(font);
    if (resolved == null) {
      return null;
    }
    final vectorFont = resolved.vectorFont;
    final renderFont = resolved.renderFont;
    if (!vectorFont.hasGlyph(code)) {
      return null;
    }

    final cache =
        _glyphCaches.putIfAbsent(renderFont, () => GlyphCache(vectorFont));
    final outline = cache.getPathForCharacterCode(code);
    if (outline.vertices().isEmpty) {
      return null;
    }

    // Compute glyph->device transform without touching the active Graphics2D
    // transform (important when drawing via an offscreen clipped layer).
    final trm = _glyphRenderingMatrix(state: state);
    final glyphMatrix = renderFont.fontMatrix.multiply(trm);

    // dart_graphics Affine.multiply() applies the RHS last (this = this * other).
    // We want: combined = base * (FontMatrix * TRM).
    final combined = _matrixToAffine(glyphMatrix)..multiply(base);

    final closed = _closeSubpathsForClip(outline);
    return _transformPath(closed, combined);
  }

  void _advanceTextPosition({required int code, required PDFont font}) {
    final state = currentGraphicsState;
    if (state == null) {
      return;
    }
    final textState = state.textState;

    final horizontalScaling = textState.horizontalScaling / 100.0;
    final fontSize = textState.fontSize;
    final charSpacing = textState.characterSpacing;
    final wordSpacing = code == 32 ? textState.wordSpacing : 0.0;

    final double width;
    if (font is PDType3Font) {
      width = _type3CharProcWidthWx ?? font.getWidthFromFont(code);
    } else if (font is PDType0Font) {
      final cid = font.cidFont;
      width = cid != null ? cid.getWidth(code) : font.getWidthFromFont(code);
    } else {
      width = font.getWidthFromFont(code);
    }
    final glyphToText = font.fontMatrix.scaleX;

    final tx = ((width * glyphToText) * fontSize + charSpacing + wordSpacing) *
        horizontalScaling;

    final textMatrix = state.textMatrix ?? Matrix();
    textMatrix.translate(tx, 0);
    state.textMatrix = textMatrix;

    if (font is PDType3Font) {
      _type3CharProcWidthWx = null;
      _type3CharProcWidthWy = null;
    }
  }

  Matrix _glyphRenderingMatrix({required PDGraphicsState state}) {
    final textState = state.textState;
    final textMatrix = state.textMatrix ?? Matrix();
    final fontSize = textState.fontSize;
    final horizontalScaling = textState.horizontalScaling / 100.0;
    final rise = textState.rise;

    final textStateMatrix = Matrix.fromComponents(
      fontSize * horizontalScaling,
      0,
      0,
      fontSize,
      0,
      rise,
    );

    // Match PDFBox: text rendering matrix = parameters * textMatrix * CTM.
    return textStateMatrix
        .multiply(textMatrix)
        .multiply(state.currentTransformationMatrix);
  }

  Affine _matrixToAffine(Matrix matrix) {
    return Affine(
      matrix.scaleX,
      matrix.shearY,
      matrix.shearX,
      matrix.scaleY,
      matrix.translateX,
      matrix.translateY,
    );
  }

  VertexStorage? _buildDeviceClipPathForCurrentPath() {
    final source = getLinePath();
    // No current path.
    if (source.vertices().isEmpty) {
      return null;
    }

    _syncTransform();
    final currentTransform = _cloneAffine(_graphics.transform);
    final closed = _closeSubpathsForClip(source);
    return _transformPath(closed, currentTransform);
  }

  VertexStorage _closeSubpathsForClip(VertexStorage path) {
    final dest = VertexStorage();
    bool hasSubpath = false;
    bool subpathClosed = true;

    for (final v in path.vertices()) {
      if (v.command.isStop) break;

      if (v.command.isMoveTo) {
        if (hasSubpath && !subpathClosed) {
          dest.closePath();
          subpathClosed = true;
        }
        hasSubpath = true;
        subpathClosed = false;
        dest.addVertex(v.x, v.y, v.command);
        continue;
      }

      dest.addVertex(v.x, v.y, v.command);
      if (v.command.isEndPoly) {
        subpathClosed = true;
      } else if (v.command.isVertex) {
        subpathClosed = false;
      }
    }

    if (hasSubpath && !subpathClosed) {
      dest.closePath();
    }

    return dest;
  }

  VertexStorage _transformPath(VertexStorage path, Affine transform) {
    final dest = VertexStorage();
    for (final v in path.vertices()) {
      if (v.command.isStop) break;
      if (v.command.isVertex) {
        final p = transform.transformPoint(v.x, v.y);
        dest.addVertex(p.x, p.y, v.command);
      } else {
        dest.addVertex(v.x, v.y, v.command);
      }
    }
    return dest;
  }

  void _invalidateClipMask() {
    _clipVersion++;
    _clipMask = null;
    _clipBounds = null;
  }

  void _ensureClipMask() {
    if (_clipEntries.isEmpty) {
      _clipMask = null;
      _clipBounds = null;
      _clipMaskVersion = _clipVersion;
      return;
    }
    if (_clipMaskVersion == _clipVersion &&
        _clipMask != null &&
        _clipBounds != null) {
      return;
    }

    final w = _graphics.width;
    final h = _graphics.height;
    if (w <= 0 || h <= 0) {
      _clipMask = null;
      _clipBounds = null;
      _clipMaskVersion = _clipVersion;
      return;
    }

    final mask = ImageBuffer(w, h);
    final maskBytes = mask.getBuffer();

    // Start fully opaque.
    for (var i = 0; i < maskBytes.length; i += 4) {
      maskBytes[i] = 255;
      maskBytes[i + 1] = 255;
      maskBytes[i + 2] = 255;
      maskBytes[i + 3] = 255;
    }

    final tmp = ImageBuffer(w, h);
    final tmpG = tmp.newGraphics2D();
    tmpG.setTransform(Affine.identity());

    _IntRect? bounds;

    for (final entry in _clipEntries) {
      // Render this clip entry into tmp as an alpha mask.
      tmpG.clear(Color(0, 0, 0, 0));
      tmpG.fillColor = Color(255, 255, 255, 255);
      tmpG.masterAlpha = 1.0;

      if (tmpG is BasicGraphics2D) {
        tmpG.rasterizer.fillingRule(
          entry.rule == PathWindingRule.evenOdd
              ? FillingRuleE.fillEvenOdd
              : FillingRuleE.fillNonZero,
        );
      }

      tmpG.beginPath();
      tmpG.currentPath.concat(entry.devicePath);
      tmpG.fillPath();

      // mask = mask * tmpAlpha
      final tmpBytes = tmp.getBuffer();
      for (var i = 0; i < maskBytes.length; i += 4) {
        final ma = maskBytes[i + 3];
        if (ma == 0) continue;
        final ta = tmpBytes[i + 3];
        final outA = (ma * ta) ~/ 255;
        maskBytes[i + 3] = outA;
      }

      final entryBounds = _boundsOfPath(entry.devicePath, w: w, h: h);
      bounds = bounds == null ? entryBounds : bounds.intersect(entryBounds);
    }

    _clipMask = mask;
    _clipBounds = bounds ?? _IntRect(0, 0, 0, 0);
    _clipMaskVersion = _clipVersion;
  }

  void _applyMaskSubset(
    ImageBuffer layer,
    ImageBuffer mask,
    int dx,
    int dy,
  ) {
    final layerBytes = layer.getBuffer();
    final maskBytes = mask.getBuffer();

    final w = layer.width;
    final h = layer.height;

    final fullW = mask.width;

    for (var y = 0; y < h; y++) {
      final maskRow = (dy + y) * fullW;
      final layerRow = y * w;
      for (var x = 0; x < w; x++) {
        final li = (layerRow + x) * 4;
        final mi = (maskRow + (dx + x)) * 4;
        final ma = maskBytes[mi + 3];
        if (ma == 255) {
          continue;
        }
        if (ma == 0) {
          layerBytes[li + 3] = 0;
          continue;
        }
        layerBytes[li] = (layerBytes[li] * ma) ~/ 255;
        layerBytes[li + 1] = (layerBytes[li + 1] * ma) ~/ 255;
        layerBytes[li + 2] = (layerBytes[li + 2] * ma) ~/ 255;
        layerBytes[li + 3] = (layerBytes[li + 3] * ma) ~/ 255;
      }
    }
  }

  _IntRect _boundsOfPath(VertexStorage path, {required int w, required int h}) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final v in path.vertices()) {
      if (v.command.isStop) break;
      if (!v.command.isVertex) continue;
      if (v.x < minX) minX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.x > maxX) maxX = v.x;
      if (v.y > maxY) maxY = v.y;
    }

    if (minX == double.infinity) {
      return _IntRect(0, 0, 0, 0);
    }

    // Expand by a pixel to be safe with antialiasing/strokes.
    final left = (minX.floor() - 1).clamp(0, w);
    final top = (minY.floor() - 1).clamp(0, h);
    final right = (maxX.ceil() + 1).clamp(0, w);
    final bottom = (maxY.ceil() + 1).clamp(0, h);

    return _IntRect(left, top, right, bottom);
  }

  ImageBuffer? _decodeImage(
    PDImageXObject image, {
    bool ignoreSoftMask = false,
    bool forMask = false,
  }) {
    final stream = image.stream;

    // For JPEGs, the DCT filter already outputs RGBA bytes by default.
    final decoded = stream.decodeWithResult(
      options: DecodeOptions.defaultOptions,
    );
    if (decoded == null) {
      return null;
    }

    final bytes = decoded.data;
    final width = image.width;
    final height = image.height;
    if (width <= 0 || height <= 0) {
      return null;
    }

    // Handle stencil images (image masks) as transparency.
    if (image.isStencil && !forMask) {
      if (image.bitsPerComponent != 1) {
        return null;
      }
      final state = currentGraphicsState;
      final maskColor = state == null
          ? Color(0, 0, 0, 255)
          : _toColor(state.nonStrokingColor);
      return _decode1BitMask(width, height, bytes, maskColor);
    }

    if (forMask) {
      return _decodeMaskImage(image, bytes, width, height);
    }

    // Fast path: already RGBA.
    final rgbaLen = width * height * 4;
    if (bytes.length == rgbaLen) {
      final buffer = ImageBuffer(width, height);
      buffer.getBuffer().setAll(0, bytes);
      return _applyImageSoftMaskIfNeeded(
        buffer,
        image,
        ignoreSoftMask: ignoreSoftMask,
      );
    }

    // Sampled images: decode into raster and convert via colorspace.
    final colorSpace = image.colorSpace;
    if (colorSpace != null && image.bitsPerComponent == 8) {
      final cpp = colorSpace.numberOfComponents;
      final expected = width * height * cpp;
      if (bytes.length >= expected) {
        final raster = PDRaster.fromBytes(
          width: width,
          height: height,
          componentsPerPixel: cpp,
          bytes: bytes,
          bitsPerComponent: image.bitsPerComponent,
        );
        final rgb = colorSpace.toRGBImage(raster);
        final rgba = rgb.getBytes(order: img.ChannelOrder.rgba, alpha: 255);
        final buffer = ImageBuffer(width, height);
        buffer.getBuffer().setAll(0, rgba);
        return _applyImageSoftMaskIfNeeded(
          buffer,
          image,
          ignoreSoftMask: ignoreSoftMask,
        );
      }
    }

    // 1-bit grayscale fallback.
    if (image.bitsPerComponent == 1) {
      return _applyImageSoftMaskIfNeeded(
        _decode1BitGray(width, height, bytes),
        image,
        ignoreSoftMask: ignoreSoftMask,
      );
    }

    return null;
  }

  ImageBuffer _applyImageSoftMaskIfNeeded(
    ImageBuffer buffer,
    PDImageXObject image, {
    required bool ignoreSoftMask,
  }) {
    if (ignoreSoftMask) {
      return buffer;
    }

    final maskStream = image.softMask ?? image.imageMaskStream;
    if (maskStream == null) {
      return buffer;
    }

    final maskImage = PDImageXObject.fromCOSStream(
      maskStream.cosStream,
      resources: currentResources,
    );
    final maskBuffer = _decodeImage(
      maskImage,
      ignoreSoftMask: true,
      forMask: true,
    );
    if (maskBuffer == null) {
      return buffer;
    }
    _applyImageMask(buffer, maskBuffer);
    return buffer;
  }

  ImageBuffer? _decodeMaskImage(
    PDImageXObject image,
    Uint8List bytes,
    int width,
    int height,
  ) {
    if (image.bitsPerComponent == 1) {
      return _decode1BitMask(width, height, bytes, Color(255, 255, 255, 255));
    }

    if (image.bitsPerComponent == 8) {
      final colorSpace = image.colorSpace;
      if (colorSpace != null) {
        final cpp = colorSpace.numberOfComponents;
        final expected = width * height * cpp;
        if (bytes.length >= expected) {
          final raster = PDRaster.fromBytes(
            width: width,
            height: height,
            componentsPerPixel: cpp,
            bytes: bytes,
            bitsPerComponent: image.bitsPerComponent,
          );
          final rgb = colorSpace.toRGBImage(raster);
          final rgba = rgb.getBytes(order: img.ChannelOrder.rgba, alpha: 255);
          return _maskFromRgba(width, height, rgba);
        }
      }

      final grayLen = width * height;
      if (bytes.length >= grayLen) {
        final out = ImageBuffer(width, height);
        final buf = out.getBuffer();
        for (var i = 0; i < grayLen; i++) {
          final g = bytes[i];
          final o = i * 4;
          buf[o] = 255;
          buf[o + 1] = 255;
          buf[o + 2] = 255;
          buf[o + 3] = g;
        }
        return out;
      }
    }

    final rgbaLen = width * height * 4;
    if (bytes.length == rgbaLen) {
      return _maskFromRgba(width, height, bytes);
    }
    final rgbLen = width * height * 3;
    if (bytes.length == rgbLen) {
      final out = ImageBuffer(width, height);
      final buf = out.getBuffer();
      for (var i = 0; i < width * height; i++) {
        final o = i * 4;
        final ri = bytes[i * 3];
        final gi = bytes[i * 3 + 1];
        final bi = bytes[i * 3 + 2];
        final a =
            ((0.299 * ri) + (0.587 * gi) + (0.114 * bi)).round().clamp(0, 255);
        buf[o] = 255;
        buf[o + 1] = 255;
        buf[o + 2] = 255;
        buf[o + 3] = a;
      }
      return out;
    }

    return null;
  }

  ImageBuffer _maskFromRgba(int width, int height, Uint8List rgba) {
    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();
    for (var i = 0; i < width * height; i++) {
      final o = i * 4;
      final r = rgba[o];
      final g = rgba[o + 1];
      final b = rgba[o + 2];
      var a = rgba[o + 3];
      if (a == 255) {
        a = ((0.299 * r) + (0.587 * g) + (0.114 * b)).round().clamp(0, 255);
      }
      buf[o] = 255;
      buf[o + 1] = 255;
      buf[o + 2] = 255;
      buf[o + 3] = a;
    }
    return out;
  }

  void _applyImageMask(ImageBuffer image, ImageBuffer mask) {
    if (image.width != mask.width || image.height != mask.height) {
      return;
    }
    final imgBuf = image.getBuffer();
    final maskBuf = mask.getBuffer();
    for (var i = 0; i < image.width * image.height; i++) {
      final o = i * 4;
      final ma = maskBuf[o + 3];
      if (ma == 255) {
        continue;
      }
      imgBuf[o + 3] = (imgBuf[o + 3] * ma) ~/ 255;
    }
  }

  ImageBuffer _decode1BitGray(int width, int height, Uint8List bytes) {
    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final bitIndex = y * width + x;
        final byteIndex = bitIndex >> 3;
        final shift = 7 - (bitIndex & 7);
        final bit = (bytes[byteIndex] >> shift) & 1;
        final g = bit == 0 ? 0 : 255;
        final o = (y * width + x) * 4;
        buf[o] = g;
        buf[o + 1] = g;
        buf[o + 2] = g;
        buf[o + 3] = 255;
      }
    }
    return out;
  }

  ImageBuffer _decode1BitMask(
    int width,
    int height,
    Uint8List bytes,
    Color maskColor,
  ) {
    final out = ImageBuffer(width, height);
    final buf = out.getBuffer();
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final bitIndex = y * width + x;
        final byteIndex = bitIndex >> 3;
        final shift = 7 - (bitIndex & 7);
        final bit = (bytes[byteIndex] >> shift) & 1;
        final o = (y * width + x) * 4;
        buf[o] = maskColor.red;
        buf[o + 1] = maskColor.green;
        buf[o + 2] = maskColor.blue;
        buf[o + 3] = bit == 0 ? 0 : maskColor.alpha;
      }
    }
    return out;
  }

  void _syncTransform() {
    final state = currentGraphicsState;
    final ctm = state?.currentTransformationMatrix;
    final ctmAffine = ctm == null
        ? Affine.identity()
        : Affine(
            ctm.scaleX,
            ctm.shearY,
            ctm.shearX,
            ctm.scaleY,
            ctm.translateX,
            ctm.translateY,
          );
    // dart_graphics Affine.multiply() applies the RHS last (this = this * other).
    // We want: combined = base * CTM.
    final combined = _cloneAffine(ctmAffine)..multiply(_xform);
    _graphics.setTransform(combined);
  }

  void _syncPaintStateForStroke() {
    final state = currentGraphicsState;
    if (state == null) return;
    _graphics.lineWidth = state.lineWidth;
    _graphics.lineCap = _mapLineCap(state.lineCap);
    _graphics.lineJoin = _mapLineJoin(state.lineJoin);
    _graphics.miterLimit = state.miterLimit;
    _graphics.strokeColor = _toColor(state.strokingColor);
    _graphics.masterAlpha = state.alphaConstant.clamp(0.0, 1.0);
  }

  void _syncPaintStateForFill() {
    final state = currentGraphicsState;
    if (state == null) return;
    _graphics.fillColor = _toColor(state.nonStrokingColor);
    _graphics.masterAlpha = state.nonStrokingAlphaConstant.clamp(0.0, 1.0);
  }

  LineJoin _mapLineJoin(int value) {
    switch (value) {
      case 1:
        return LineJoin.round;
      case 2:
        return LineJoin.bevel;
      case 0:
      default:
        return LineJoin.miter;
    }
  }

  LineCap _mapLineCap(int value) {
    switch (value) {
      case 1:
        return LineCap.round;
      case 2:
        return LineCap.square;
      case 0:
      default:
        return LineCap.butt;
    }
  }

  void _setFillRule(PathWindingRule rule) {
    final g = _graphics;
    if (g is BasicGraphics2D) {
      g.rasterizer.fillingRule(
        rule == PathWindingRule.evenOdd
            ? FillingRuleE.fillEvenOdd
            : FillingRuleE.fillNonZero,
      );
    }
  }

  Color _toColor(PDColor pdColor) {
    final rgb = pdColor.toRGB();
    final r = (rgb.isNotEmpty ? rgb[0] : 0.0).clamp(0.0, 1.0);
    final g = (rgb.length > 1 ? rgb[1] : 0.0).clamp(0.0, 1.0);
    final b = (rgb.length > 2 ? rgb[2] : 0.0).clamp(0.0, 1.0);
    return Color(
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
      255,
    );
  }

  Affine _cloneAffine(Affine src) =>
      Affine(src.sx, src.shy, src.shx, src.sy, src.tx, src.ty);
}

class _ClipEntry {
  const _ClipEntry(this.devicePath, this.rule);

  final VertexStorage devicePath;
  final PathWindingRule rule;
}

class VectorFontResolution {
  VectorFontResolution(this.vectorFont, this.renderFont);

  final PDVectorFont vectorFont;
  final PDFont renderFont;
}

class _IntRect {
  const _IntRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isEmpty => right <= left || bottom <= top;

  int get width => right - left;
  int get height => bottom - top;

  _IntRect intersect(_IntRect other) {
    final l = left > other.left ? left : other.left;
    final t = top > other.top ? top : other.top;
    final r = right < other.right ? right : other.right;
    final b = bottom < other.bottom ? bottom : other.bottom;
    return _IntRect(l, t, r, b);
  }
}


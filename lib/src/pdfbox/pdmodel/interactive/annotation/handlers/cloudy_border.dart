import 'dart:math';

import '../../../common/pd_rectangle.dart';
import '../../../pd_appearance_content_stream.dart';

/// Generates annotation appearances with a cloudy border.
///
/// Dashed stroke styles are not recommended with cloudy borders. The result would
/// not look good because some parts of the arcs are traced twice by the stroked
/// path. Actually Acrobat Reader's line style dialog does not allow to choose a
/// dashed and a cloudy style at the same time.
///
/// TODO: This is a partial implementation. Full cloudy border support requires:
/// - cloudyPolygonImpl with proper arc calculations
/// - cloudyEllipseImpl with proper curl placement
/// - Full handling of corner curls and intermediate curls
class CloudyBorder {
  // Angle constants for cloudy border calculations
  // Some are reserved for future full implementation
  // ignore: unused_field
  static const double _angle180Deg = pi;
  // ignore: unused_field
  static const double _angle90Deg = pi / 2;
  static const double _angle34Deg = 34 * pi / 180;
  // ignore: unused_field
  static const double _angle30Deg = 30 * pi / 180;
  // ignore: unused_field
  static const double _angle12Deg = 12 * pi / 180;

  final PDAppearanceContentStream output;
  final PDRectangle annotRect;
  final double intensity;
  final double lineWidth;
  
  PDRectangle? _rectWithDiff;
  bool _outputStarted = false;
  double _bboxMinX = 0;
  double _bboxMinY = 0;
  double _bboxMaxX = 0;
  double _bboxMaxY = 0;

  /// Creates a new CloudyBorder that writes to the specified content stream.
  ///
  /// @param stream content stream
  /// @param intensity intensity of cloudy effect (entry I); typically 1.0 or 2.0
  /// @param lineWidth line width for annotation border (entry W)
  /// @param rect annotation rectangle (entry Rect)
  CloudyBorder(this.output, this.intensity, this.lineWidth, this.annotRect);

  /// Creates a cloudy border for a rectangular annotation.
  /// The rectangle is specified by the RD entry and the
  /// Rect entry that was passed in to the constructor.
  ///
  /// This can be used for Square and FreeText annotations.
  void createCloudyRectangle(PDRectangle? rd) {
    _rectWithDiff = _applyRectDiff(rd, lineWidth / 2);
    final left = _rectWithDiff!.lowerLeftX;
    final bottom = _rectWithDiff!.lowerLeftY;
    final right = _rectWithDiff!.upperRightX;
    final top = _rectWithDiff!.upperRightY;

    _cloudyRectangleImpl(left, bottom, right, top, false);
    _finish();
  }

  /// Creates a cloudy border for a Polygon annotation.
  void createCloudyPolygon(List<List<double>> path) {
    final n = path.length;
    final polygon = <Point<double>>[];

    for (int i = 0; i < n; i++) {
      final array = path[i];
      if (array.length == 2) {
        polygon.add(Point(array[0], array[1]));
      } else if (array.length == 6) {
        // TODO Curve segments are not yet supported in cloudy border.
        polygon.add(Point(array[4], array[5]));
      }
    }

    _cloudyPolygonImpl(polygon, false);
    _finish();
  }

  /// Creates a cloudy border for a Circle annotation.
  void createCloudyEllipse(PDRectangle? rd) {
    _rectWithDiff = _applyRectDiff(rd, 0);
    final left = _rectWithDiff!.lowerLeftX;
    final bottom = _rectWithDiff!.lowerLeftY;
    final right = _rectWithDiff!.upperRightX;
    final top = _rectWithDiff!.upperRightY;

    _cloudyEllipseImpl(left, bottom, right, top);
    _finish();
  }

  /// Returns the BBox entry (bounding box) for the appearance stream form XObject.
  PDRectangle getBBox() => getRectangle();

  /// Returns the updated Rect entry for the annotation.
  PDRectangle getRectangle() {
    return PDRectangle(
      _bboxMinX, _bboxMinY, _bboxMaxX - _bboxMinX, _bboxMaxY - _bboxMinY);
  }

  /// Returns the updated RD entry for Square and Circle annotations.
  PDRectangle getRectDifference() {
    final d = lineWidth / 2;
    if (_rectWithDiff == null) {
      return PDRectangle(d, d, lineWidth, lineWidth);
    }

    final re = _rectWithDiff!;
    final left = re.lowerLeftX - _bboxMinX;
    final bottom = re.lowerLeftY - _bboxMinY;
    final right = _bboxMaxX - re.upperRightX;
    final top = _bboxMaxY - re.upperRightY;

    return PDRectangle(left, bottom, right - left, top - bottom);
  }

  PDRectangle _applyRectDiff(PDRectangle? rd, double minVal) {
    var rectLeft = annotRect.lowerLeftX;
    var rectBottom = annotRect.lowerLeftY;
    var rectRight = annotRect.upperRightX;
    var rectTop = annotRect.upperRightY;

    // Normalize
    rectLeft = min(rectLeft, rectRight);
    rectBottom = min(rectBottom, rectTop);
    rectRight = max(rectLeft, rectRight);
    rectTop = max(rectBottom, rectTop);

    double rdLeft, rdBottom, rdRight, rdTop;

    if (rd != null) {
      rdLeft = max(rd.lowerLeftX, minVal);
      rdBottom = max(rd.lowerLeftY, minVal);
      rdRight = max(rd.upperRightX, minVal);
      rdTop = max(rd.upperRightY, minVal);
    } else {
      rdLeft = minVal;
      rdBottom = minVal;
      rdRight = minVal;
      rdTop = minVal;
    }

    rectLeft += rdLeft;
    rectBottom += rdBottom;
    rectRight -= rdRight;
    rectTop -= rdTop;

    return PDRectangle(
        rectLeft, rectBottom, rectRight - rectLeft, rectTop - rectBottom);
  }

  void _cloudyRectangleImpl(
      double left, double bottom, double right, double top, bool isEllipse) {
    final w = right - left;
    final h = top - bottom;

    if (intensity <= 0.0) {
      output.addRect(left, bottom, w, h);
      _bboxMinX = left;
      _bboxMinY = bottom;
      _bboxMaxX = right;
      _bboxMaxY = top;
      return;
    }

    // Make a polygon with direction equal to the positive angle direction.
    List<Point<double>> polygon;

    if (w < 1.0) {
      polygon = [
        Point(left, bottom),
        Point(left, top),
        Point(left, bottom),
      ];
    } else if (h < 1.0) {
      polygon = [
        Point(left, bottom),
        Point(right, bottom),
        Point(left, bottom),
      ];
    } else {
      polygon = [
        Point(left, bottom),
        Point(right, bottom),
        Point(right, top),
        Point(left, top),
        Point(left, bottom),
      ];
    }

    _cloudyPolygonImpl(polygon, isEllipse);
  }

  void _cloudyPolygonImpl(List<Point<double>> vertices, bool isEllipse) {
    final polygon = _removeZeroLengthSegments(vertices);
    _getPositivePolygon(polygon);
    final numPoints = polygon.length;

    if (numPoints < 2) {
      return;
    }

    if (intensity <= 0.0) {
      _moveTo(polygon[0].x, polygon[0].y);
      for (int i = 1; i < numPoints; i++) {
        _lineTo(polygon[i].x, polygon[i].y);
      }
      return;
    }

    var cloudRadius =
        isEllipse ? _getEllipseCloudRadius() : _getPolygonCloudRadius();

    if (cloudRadius < 0.5) {
      cloudRadius = 0.5;
    }

    final k = cos(_angle34Deg);
    final advIntermDefault = 2 * k * cloudRadius;
    // Reserved for full implementation with corner curls
    // final advCornerDefault = k * cloudRadius;

    // Simplified implementation: draw arcs at corners
    // Full implementation would compute proper curl placement
    for (int j = 0; j + 1 < numPoints; j++) {
      final pt = polygon[j];
      final ptNext = polygon[j + 1];
      
      if (j == 0) {
        _moveTo(pt.x, pt.y);
      }
      
      // Draw simplified curls along the edge
      final dx = ptNext.x - pt.x;
      final dy = ptNext.y - pt.y;
      final length = sqrt(dx * dx + dy * dy);
      
      if (length < advIntermDefault) {
        _lineTo(ptNext.x, ptNext.y);
        continue;
      }
      
      final numCurls = (length / advIntermDefault).floor();
      final ux = dx / length;
      final uy = dy / length;
      final perpX = -uy;
      final perpY = ux;
      
      var x = pt.x;
      var y = pt.y;
      final step = length / (numCurls > 0 ? numCurls : 1);
      
      for (int i = 0; i < numCurls; i++) {
        // Draw a simple arc (curl)
        final midX = x + step * 0.5 * ux;
        final midY = y + step * 0.5 * uy;
        final peakX = midX + cloudRadius * 0.7 * perpX;
        final peakY = midY + cloudRadius * 0.7 * perpY;
        final endX = x + step * ux;
        final endY = y + step * uy;
        
        output.curveTo(
          x + step * 0.25 * ux + cloudRadius * 0.35 * perpX,
          y + step * 0.25 * uy + cloudRadius * 0.35 * perpY,
          peakX, peakY,
          midX, midY + cloudRadius * 0.5 * perpY,
        );
        output.curveTo(
          midX + step * 0.25 * ux + cloudRadius * 0.35 * perpX,
          midY + step * 0.25 * uy + cloudRadius * 0.35 * perpY,
          endX - step * 0.1 * ux, endY - step * 0.1 * uy,
          endX, endY,
        );
        
        x = endX;
        y = endY;
      }
      
      _lineTo(ptNext.x, ptNext.y);
    }
  }

  void _cloudyEllipseImpl(double left, double bottom, double right, double top) {
    if (intensity <= 0.0) {
      _drawBasicEllipse(left, bottom, right, top);
      return;
    }

    final width = right - left;
    final height = top - bottom;
    final cloudRadius = _getEllipseCloudRadius();

    // Omit cloudy border if the ellipse is very small
    final threshold1 = 0.50 * cloudRadius;
    if (width < threshold1 && height < threshold1) {
      _drawBasicEllipse(left, bottom, right, top);
      return;
    }

    // Draw a cloudy rectangle instead of an ellipse when the
    // width or height is very small
    const threshold2 = 5.0;
    if ((width < threshold2 && height > 20) ||
        (width > 20 && height < threshold2)) {
      _cloudyRectangleImpl(left, bottom, right, top, true);
      return;
    }

    // For now, draw basic ellipse instead of fully implementing cloudy effect
    // Discretize ellipse to polygon and delegate to _cloudyPolygonImpl
    // Use enough segments for smoothness relative to size
    final perimeter = pi * (width + height) / 2; // Approximate
    final segments = max(12, (perimeter / 5).ceil());
    
    final rx = width / 2;
    final ry = height / 2;
    final cx = left + rx;
    final cy = bottom + ry;
    
    final points = <Point<double>>[];
    for (int i = 0; i < segments; i++) {
        final angle = 2 * pi * i / segments;
        points.add(Point(cx + rx * cos(angle), cy + ry * sin(angle)));
    }
    
    // Close loop
    points.add(points[0]);
    
    _cloudyPolygonImpl(points, true);
  }

  void _drawBasicEllipse(
      double left, double bottom, double right, double top) {
    final rx = (right - left).abs() / 2;
    final ry = (top - bottom).abs() / 2;
    final cx = (left + right) / 2;
    final cy = (bottom + top) / 2;

    // Draw ellipse using Bezier curves
    const magic = 0.551915024494;
    final mx = rx * magic;
    final my = ry * magic;

    _moveTo(cx + rx, cy);
    output.curveTo(cx + rx, cy + my, cx + mx, cy + ry, cx, cy + ry);
    output.curveTo(cx - mx, cy + ry, cx - rx, cy + my, cx - rx, cy);
    output.curveTo(cx - rx, cy - my, cx - mx, cy - ry, cx, cy - ry);
    output.curveTo(cx + mx, cy - ry, cx + rx, cy - my, cx + rx, cy);
    output.closePath();
    
    _bboxMinX = left;
    _bboxMinY = bottom;
    _bboxMaxX = right;
    _bboxMaxY = top;
  }

  List<Point<double>> _removeZeroLengthSegments(List<Point<double>> polygon) {
    if (polygon.length <= 2) {
      return polygon;
    }

    const toler = 0.50;
    final result = <Point<double>>[];
    Point<double>? ptPrev;

    for (final pt in polygon) {
      if (ptPrev == null ||
          (pt.x - ptPrev.x).abs() >= toler ||
          (pt.y - ptPrev.y).abs() >= toler) {
        result.add(pt);
      }
      ptPrev = pt;
    }

    return result;
  }

  void _getPositivePolygon(List<Point<double>> points) {
    if (_getPolygonDirection(points) < 0) {
      // Reverse the polygon
      for (int i = 0; i < points.length ~/ 2; i++) {
        final j = points.length - i - 1;
        final temp = points[i];
        points[i] = points[j];
        points[j] = temp;
      }
    }
  }

  double _getPolygonDirection(List<Point<double>> points) {
    double a = 0;
    final len = points.length;
    for (int i = 0; i < len; i++) {
      final j = (i + 1) % len;
      a += points[i].x * points[j].y - points[i].y * points[j].x;
    }
    return a;
  }

  void _beginOutput(double x, double y) {
    _bboxMinX = x;
    _bboxMinY = y;
    _bboxMaxX = x;
    _bboxMaxY = y;
    _outputStarted = true;
    // Set line join to bevel to avoid spikes
    output.setLineJoinStyle(2);
  }

  void _updateBBox(double x, double y) {
    _bboxMinX = min(_bboxMinX, x);
    _bboxMinY = min(_bboxMinY, y);
    _bboxMaxX = max(_bboxMaxX, x);
    _bboxMaxY = max(_bboxMaxY, y);
  }

  void _moveTo(double x, double y) {
    if (_outputStarted) {
      _updateBBox(x, y);
    } else {
      _beginOutput(x, y);
    }
    output.moveTo(x, y);
  }

  void _lineTo(double x, double y) {
    if (_outputStarted) {
      _updateBBox(x, y);
    } else {
      _beginOutput(x, y);
    }
    output.lineTo(x, y);
  }

  void _finish() {
    if (_outputStarted) {
      output.closePath();
    }

    if (lineWidth > 0) {
      final d = lineWidth / 2;
      _bboxMinX -= d;
      _bboxMinY -= d;
      _bboxMaxX += d;
      _bboxMaxY += d;
    }
  }

  double _getEllipseCloudRadius() {
    // Equation deduced from Acrobat Reader's appearance streams. Circle
    // annotations have a slightly larger radius than Polygons and Squares.
    return 4.75 * intensity + 0.5 * lineWidth;
  }

  double _getPolygonCloudRadius() {
    // Equation deduced from Acrobat Reader's appearance streams.
    return 4 * intensity + 0.5 * lineWidth;
  }
}

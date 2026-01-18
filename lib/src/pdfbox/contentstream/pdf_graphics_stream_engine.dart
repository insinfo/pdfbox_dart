import 'package:dart_graphics/dart_graphics.dart';

import 'pdf_stream_engine.dart';

/// Minimal port of PDFBox's `PDFGraphicsStreamEngine`.
///
/// It keeps track of the current path while delegating painting to subclasses.
///
/// This class intentionally mirrors the PDFBox naming to reduce the risk of
/// subtle rendering differences.
class PDFGraphicsStreamEngine extends PDFStreamEngine {
  PDFGraphicsStreamEngine({super.operators});

  final VertexStorage _linePath = VertexStorage();

  double _currentX = 0;
  double _currentY = 0;
  double _subpathStartX = 0;
  double _subpathStartY = 0;
  bool _hasCurrentPoint = false;

  /// Returns the current line path. Reset after each fill/stroke.
  VertexStorage getLinePath() => _linePath;

  /// Resets the current line path.
  void resetLinePath() {
    _linePath.clear();
    _hasCurrentPoint = false;
    _currentX = 0;
    _currentY = 0;
    _subpathStartX = 0;
    _subpathStartY = 0;
  }

  @override
  void moveTo(double x, double y) {
    _linePath.moveTo(x, y);
    _currentX = x;
    _currentY = y;
    _subpathStartX = x;
    _subpathStartY = y;
    _hasCurrentPoint = true;
  }

  @override
  void lineTo(double x, double y) {
    if (!_hasCurrentPoint) {
      moveTo(x, y);
      return;
    }
    _linePath.lineTo(x, y);
    _currentX = x;
    _currentY = y;
  }

  @override
  void curveTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    if (!_hasCurrentPoint) {
      moveTo(x3, y3);
      return;
    }
    _linePath.curve4(x1, y1, x2, y2, x3, y3);
    _currentX = x3;
    _currentY = y3;
  }

  @override
  void curveToReplicateInitialPoint(double x2, double y2, double x3, double y3) {
    if (!_hasCurrentPoint) {
      moveTo(x3, y3);
      return;
    }
    curveTo(_currentX, _currentY, x2, y2, x3, y3);
  }

  @override
  void curveToReplicateFinalPoint(double x1, double y1, double x3, double y3) {
    if (!_hasCurrentPoint) {
      moveTo(x3, y3);
      return;
    }
    curveTo(x1, y1, x3, y3, x3, y3);
  }

  @override
  void closePath() {
    if (!_hasCurrentPoint) {
      return;
    }
    _linePath.closePath();
    _currentX = _subpathStartX;
    _currentY = _subpathStartY;
  }

  @override
  void appendRectangle(double x, double y, double width, double height) {
    final x2 = x + width;
    final y2 = y + height;
    _linePath
      ..moveTo(x, y)
      ..lineTo(x2, y)
      ..lineTo(x2, y2)
      ..lineTo(x, y2)
      ..closePath();
    _currentX = x;
    _currentY = y;
    _subpathStartX = x;
    _subpathStartY = y;
    _hasCurrentPoint = true;
  }
}

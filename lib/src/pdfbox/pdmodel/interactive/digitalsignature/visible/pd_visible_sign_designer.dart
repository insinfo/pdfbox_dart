import 'dart:typed_data';

import 'package:dart_graphics/dart_graphics.dart';

import '../../../pd_document.dart';

/// Class for visible signature design properties.
///
/// Setters use fluently/chaining style to allow:
/// `designer.xAxis(100).yAxis(100).width(200).height(50);`
class PDVisibleSignDesigner {
  double? _imageWidth;
  double? _imageHeight;
  double _xAxis = 0;
  double _yAxis = 0;
  double _pageHeight = 0;
  double _pageWidth = 0;
  Uint8List? _imageBytes;
  String _signatureFieldName = 'sig';
  List<int> _formatterRectangleParameters = [0, 0, 100, 50];
  Affine _affineTransform = Affine.identity();
  double _imageSizeInPercents = 100;
  int _rotation = 0;

  /// Default constructor.
  PDVisibleSignDesigner();

  /// Create from an image and PDF document details.
  factory PDVisibleSignDesigner.fromDocument(
      PDDocument document, Uint8List? imageBytes, int page,
      {double? imageWidth, double? imageHeight}) {
    final designer = PDVisibleSignDesigner();
    designer._imageBytes = imageBytes;
    if (imageWidth != null) designer._imageWidth = imageWidth;
    if (imageHeight != null) designer._imageHeight = imageHeight;

    if (imageWidth != null && imageHeight != null) {
      designer._formatterRectangleParameters[2] = imageWidth.toInt();
      designer._formatterRectangleParameters[3] = imageHeight.toInt();
    }

    designer._calculatePageSize(document, page);
    return designer;
  }

  /// Create from bytes and page number (will load the PDF to get page size).
  static Future<PDVisibleSignDesigner> fromBytes(
      Uint8List pdfBytes, Uint8List? imageBytes, int page,
      {double? imageWidth, double? imageHeight}) async {
    final document = await PDDocument.loadFromBytes(pdfBytes);
    try {
      return PDVisibleSignDesigner.fromDocument(document, imageBytes, page,
          imageWidth: imageWidth, imageHeight: imageHeight);
    } finally {
      document.close();
    }
  }

  void _calculatePageSize(PDDocument document, int page) {
    if (page < 1) {
      throw ArgumentError('First page of pdf is 1, not $page');
    }

    final p = document.getPage(page - 1);
    final mediaBox = p.mediaBox;
    if (mediaBox == null) {
       throw StateError('Page $page is missing MediaBox');
    }
    _pageHeight = mediaBox.height;
    _pageWidth = mediaBox.width;
    _imageSizeInPercents = 100;
    _rotation = p.rotation % 360;
  }

  /// Adjust signature for page rotation.
  PDVisibleSignDesigner adjustForRotation() {
    switch (_rotation) {
      case 90:
        final tempY = _yAxis;
        _yAxis = _pageHeight - _xAxis - (_imageWidth ?? 0);
        _xAxis = tempY;

        _affineTransform = Affine(
          0,
          (_imageHeight ?? 0) / (_imageWidth ?? 1),
          -(_imageWidth ?? 0) / (_imageHeight ?? 1),
          0,
          (_imageWidth ?? 0),
          0,
        );

        final tempHeight = _imageHeight;
        _imageHeight = _imageWidth;
        _imageWidth = tempHeight;
        break;

      case 180:
        final newX = _pageWidth - _xAxis - (_imageWidth ?? 0);
        final newY = _pageHeight - _yAxis - (_imageHeight ?? 0);
        _xAxis = newX;
        _yAxis = newY;

        _affineTransform = Affine(-1, 0, 0, -1, (_imageWidth ?? 0), (_imageHeight ?? 0));
        break;

      case 270:
        final tempX = _xAxis;
        _xAxis = _pageWidth - _yAxis - (_imageHeight ?? 0);
        _yAxis = tempX;

        _affineTransform = Affine(
          0,
          -(_imageHeight ?? 0) / (_imageWidth ?? 1),
          (_imageWidth ?? 0) / (_imageHeight ?? 1),
          0,
          0,
          (_imageHeight ?? 0),
        );

        final tempHeight = _imageHeight;
        _imageHeight = _imageWidth;
        _imageWidth = tempHeight;
        break;

      case 0:
      default:
        break;
    }
    return this;
  }

  PDVisibleSignDesigner imageSize(double width, double height) {
    _imageWidth = width;
    _imageHeight = height;
    _formatterRectangleParameters[2] = width.toInt();
    _formatterRectangleParameters[3] = height.toInt();
    return this;
  }

  PDVisibleSignDesigner zoom(double percent) {
    if (_imageHeight != null) _imageHeight = _imageHeight! + (_imageHeight! * percent) / 100;
    if (_imageWidth != null) _imageWidth = _imageWidth! + (_imageWidth! * percent) / 100;

    _formatterRectangleParameters[2] = (_imageWidth ?? 0).toInt();
    _formatterRectangleParameters[3] = (_imageHeight ?? 0).toInt();
    return this;
  }

  PDVisibleSignDesigner coordinates(double x, double y) {
    _xAxis = x;
    _yAxis = y;
    return this;
  }

  double get xAxisValue => _xAxis;
  PDVisibleSignDesigner xAxis(double value) {
    _xAxis = value;
    return this;
  }

  double get yAxisValue => _yAxis;
  PDVisibleSignDesigner yAxis(double value) {
    _yAxis = value;
    return this;
  }

  double get widthValue => _imageWidth ?? 0;
  PDVisibleSignDesigner width(double value) {
    _imageWidth = value;
    _formatterRectangleParameters[2] = value.toInt();
    return this;
  }

  double get heightValue => _imageHeight ?? 0;
  PDVisibleSignDesigner height(double value) {
    _imageHeight = value;
    _formatterRectangleParameters[3] = value.toInt();
    return this;
  }

  String get signatureFieldNameValue => _signatureFieldName;
  PDVisibleSignDesigner signatureFieldName(String value) {
    _signatureFieldName = value;
    return this;
  }

  Uint8List? get imageBytes => _imageBytes;
  PDVisibleSignDesigner image(Uint8List bytes) {
    _imageBytes = bytes;
    return this;
  }

  Affine get transform => _affineTransform;
  PDVisibleSignDesigner setTransform(Affine value) {
    _affineTransform = value.clone();
    return this;
  }

  List<int> get formatterRectangleParameters => _formatterRectangleParameters;
  PDVisibleSignDesigner setFormatterRectangleParameters(List<int> value) {
    _formatterRectangleParameters = List.from(value);
    return this;
  }

  double get pageWidth => _pageWidth;
  PDVisibleSignDesigner setPageWidth(double value) {
    _pageWidth = value;
    return this;
  }

  double get pageHeight => _pageHeight;
  PDVisibleSignDesigner setPageHeight(double value) {
    _pageHeight = value;
    return this;
  }

  double get imageSizeInPercents => _imageSizeInPercents;
  PDVisibleSignDesigner setImageSizeInPercents(double value) {
    _imageSizeInPercents = value;
    return this;
  }
}

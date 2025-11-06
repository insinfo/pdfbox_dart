import 'dart:typed_data';

/// Aggregates selected header table values for quick inspection during font scans.
class FontHeaders {
  static const int bytesGcid = 142;

  String? _error;
  String? _name;
  int? _headerMacStyle;
  dynamic _os2Windows;
  String? _fontFamily;
  String? _fontSubFamily;
  Uint8List? _nonOtfGcid142;
  bool _isOtfAndPostScript = false;
  String? _otfRegistry;
  String? _otfOrdering;
  int _otfSupplement = 0;

  String? get error => _error;
  String? get name => _name;
  int? get headerMacStyle => _headerMacStyle;
  dynamic get os2Windows => _os2Windows;
  String? get fontFamily => _fontFamily;
  String? get fontSubFamily => _fontSubFamily;
  bool get isOpenTypePostScript => _isOtfAndPostScript;
  Uint8List? get nonOtfTableGcid142 => _nonOtfGcid142;
  String? get otfRegistry => _otfRegistry;
  String? get otfOrdering => _otfOrdering;
  int get otfSupplement => _otfSupplement;

  void setError(String? value) => _error = value;
  void setName(String? value) => _name = value;
  void setHeaderMacStyle(int? value) => _headerMacStyle = value;
  void setOs2Windows(dynamic value) => _os2Windows = value;

  void setFontFamily(String? family, String? subFamily) {
    _fontFamily = family;
    _fontSubFamily = subFamily;
  }

  void setNonOtfGcid142(Uint8List? value) => _nonOtfGcid142 = value == null ? null : Uint8List.fromList(value);

  void setIsOtfAndPostScript(bool value) => _isOtfAndPostScript = value;

  void setOtfRos(String? registry, String? ordering, int supplement) {
    _otfRegistry = registry;
    _otfOrdering = ordering;
    _otfSupplement = supplement;
  }
}

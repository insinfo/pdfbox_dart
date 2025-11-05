import '../util/bounding_box.dart';
import 'char_metric.dart';
import 'composite.dart';
import 'kern_pair.dart';
import 'track_kern.dart';

class FontMetrics {
  double _afmVersion = 0;
  int _metricSets = 0;
  String? _fontName;
  String? _fullName;
  String? _familyName;
  String? _weight;
  BoundingBox? _fontBBox;
  String? _fontVersion;
  String? _notice;
  String? _encodingScheme;
  int _mappingScheme = 0;
  int _escChar = 0;
  String? _characterSet;
  int _characters = 0;
  bool _isBaseFont = true;
  List<double>? _vVector;
  bool? _isFixedV;
  double _capHeight = 0;
  double _xHeight = 0;
  double _ascender = 0;
  double _descender = 0;
  final List<String> _comments = <String>[];

  double _underlinePosition = 0;
  double _underlineThickness = 0;
  double _italicAngle = 0;
  List<double>? _charWidth;
  bool _isFixedPitch = false;
  double _standardHorizontalWidth = 0;
  double _standardVerticalWidth = 0;

  final List<CharMetric> _charMetrics = <CharMetric>[];
  final Map<String, CharMetric> _charMetricsMap = <String, CharMetric>{};
  final List<TrackKern> _trackKern = <TrackKern>[];
  final List<Composite> _composites = <Composite>[];
  final List<KernPair> _kernPairs = <KernPair>[];
  final List<KernPair> _kernPairs0 = <KernPair>[];
  final List<KernPair> _kernPairs1 = <KernPair>[];

  double getCharacterWidth(String name) {
    final metric = _charMetricsMap[name];
    return metric?.getWx() ?? 0;
  }

  double getCharacterHeight(String name) {
    final metric = _charMetricsMap[name];
    if (metric == null) {
      return 0;
    }

    var result = metric.getWy();
    if (result == 0) {
      final box = metric.getBoundingBox();
      if (box != null) {
        result = box.height;
      }
    }
    return result;
  }

  double getAverageCharacterWidth() {
    double totalWidths = 0;
    var characterCount = 0;
    for (final metric in _charMetrics) {
      final width = metric.getWx();
      if (width > 0) {
        totalWidths += width;
        characterCount++;
      }
    }
    return characterCount == 0 ? 0 : totalWidths / characterCount;
  }

  void addComment(String comment) {
    _comments.add(comment);
  }

  List<String> getComments() => List.unmodifiable(_comments);

  double getAFMVersion() => _afmVersion;

  int getMetricSets() => _metricSets;

  void setAFMVersion(double afmVersion) {
    _afmVersion = afmVersion;
  }

  void setMetricSets(int metricSets) {
    if (metricSets < 0 || metricSets > 2) {
      throw ArgumentError.value(
        metricSets,
        'metricSets',
        'Metric sets must be in {0,1,2}',
      );
    }
    _metricSets = metricSets;
  }

  String? getFontName() => _fontName;

  void setFontName(String? name) {
    _fontName = name;
  }

  String? getFullName() => _fullName;

  void setFullName(String? fullName) {
    _fullName = fullName;
  }

  String? getFamilyName() => _familyName;

  void setFamilyName(String? familyName) {
    _familyName = familyName;
  }

  String? getWeight() => _weight;

  void setWeight(String? weight) {
    _weight = weight;
  }

  BoundingBox? getFontBBox() => _fontBBox;

  void setFontBBox(BoundingBox? fontBBox) {
    _fontBBox = fontBBox;
  }

  String? getNotice() => _notice;

  void setNotice(String? notice) {
    _notice = notice;
  }

  String? getEncodingScheme() => _encodingScheme;

  void setEncodingScheme(String? encodingScheme) {
    _encodingScheme = encodingScheme;
  }

  int getMappingScheme() => _mappingScheme;

  void setMappingScheme(int mappingScheme) {
    _mappingScheme = mappingScheme;
  }

  int getEscChar() => _escChar;

  void setEscChar(int escChar) {
    _escChar = escChar;
  }

  String? getCharacterSet() => _characterSet;

  void setCharacterSet(String? characterSet) {
    _characterSet = characterSet;
  }

  int getCharacters() => _characters;

  void setCharacters(int characters) {
    _characters = characters;
  }

  bool getIsBaseFont() => _isBaseFont;

  void setIsBaseFont(bool isBaseFont) {
    _isBaseFont = isBaseFont;
  }

  List<double>? getVVector() => _vVector;

  void setVVector(List<double>? vVector) {
    _vVector = vVector;
  }

  bool getIsFixedV() => _isFixedV ?? _vVector != null;

  void setIsFixedV(bool isFixedV) {
    _isFixedV = isFixedV;
  }

  double getCapHeight() => _capHeight;

  void setCapHeight(double capHeight) {
    _capHeight = capHeight;
  }

  double getXHeight() => _xHeight;

  void setXHeight(double xHeight) {
    _xHeight = xHeight;
  }

  double getAscender() => _ascender;

  void setAscender(double ascender) {
    _ascender = ascender;
  }

  double getDescender() => _descender;

  void setDescender(double descender) {
    _descender = descender;
  }

  String? getFontVersion() => _fontVersion;

  void setFontVersion(String? fontVersion) {
    _fontVersion = fontVersion;
  }

  double getUnderlinePosition() => _underlinePosition;

  void setUnderlinePosition(double underlinePosition) {
    _underlinePosition = underlinePosition;
  }

  double getUnderlineThickness() => _underlineThickness;

  void setUnderlineThickness(double underlineThickness) {
    _underlineThickness = underlineThickness;
  }

  double getItalicAngle() => _italicAngle;

  void setItalicAngle(double italicAngle) {
    _italicAngle = italicAngle;
  }

  List<double>? getCharWidth() => _charWidth;

  void setCharWidth(List<double>? charWidth) {
    _charWidth = charWidth;
  }

  bool getIsFixedPitch() => _isFixedPitch;

  void setFixedPitch(bool isFixedPitch) {
    _isFixedPitch = isFixedPitch;
  }

  List<CharMetric> getCharMetrics() => List.unmodifiable(_charMetrics);

  void addCharMetric(CharMetric metric) {
    _charMetrics.add(metric);
    final name = metric.getName();
    if (name != null) {
      _charMetricsMap[name] = metric;
    }
  }

  List<TrackKern> getTrackKern() => List.unmodifiable(_trackKern);

  void addTrackKern(TrackKern kern) {
    _trackKern.add(kern);
  }

  List<Composite> getComposites() => List.unmodifiable(_composites);

  void addComposite(Composite composite) {
    _composites.add(composite);
  }

  List<KernPair> getKernPairs() => List.unmodifiable(_kernPairs);

  void addKernPair(KernPair kernPair) {
    _kernPairs.add(kernPair);
  }

  List<KernPair> getKernPairs0() => List.unmodifiable(_kernPairs0);

  void addKernPair0(KernPair kernPair) {
    _kernPairs0.add(kernPair);
  }

  List<KernPair> getKernPairs1() => List.unmodifiable(_kernPairs1);

  void addKernPair1(KernPair kernPair) {
    _kernPairs1.add(kernPair);
  }

  double getStandardHorizontalWidth() => _standardHorizontalWidth;

  void setStandardHorizontalWidth(double standardHorizontalWidth) {
    _standardHorizontalWidth = standardHorizontalWidth;
  }

  double getStandardVerticalWidth() => _standardVerticalWidth;

  void setStandardVerticalWidth(double standardVerticalWidth) {
    _standardVerticalWidth = standardVerticalWidth;
  }
}

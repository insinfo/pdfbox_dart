import 'dart:io';

import '../../../fontbox/afm/afm_parser.dart';
import '../../../fontbox/afm/font_metrics.dart';

class Standard14Font {
  Standard14Font._(
    this.postScriptName,
    this.afmResource, {
    this.aliases = const <String>[],
  });

  final String postScriptName;
  final String afmResource;
  final List<String> aliases;

  late final FontMetrics _metrics = _loadMetrics();

  FontMetrics get metrics => _metrics;

  FontMetrics _loadMetrics() {
    final path = 'resources/afm/$afmResource';
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'AFM resource "$afmResource" for $postScriptName not found at $path',
      );
    }
    final parser = AFMParser(file.readAsBytesSync());
    return parser.parse();
  }

  bool matches(String name) =>
      name == postScriptName || aliases.any((alias) => alias == name);
}

class Standard14Fonts {
  static final List<Standard14Font> _fonts = <Standard14Font>[
    Standard14Font._(
      'Courier',
      'Courier.afm',
      aliases: <String>[
        'CourierNew',
        'CourierCourierNew',
        'CourierNewPSMT',
      ],
    ),
    Standard14Font._(
      'Courier-Bold',
      'Courier-Bold.afm',
      aliases: <String>[
        'CourierNew,Bold',
        'CourierNew-Bold',
        'CourierNewPS-BoldMT',
      ],
    ),
    Standard14Font._(
      'Courier-Oblique',
      'Courier-Oblique.afm',
      aliases: <String>[
        'CourierNew,Italic',
        'CourierNew-Italic',
        'CourierNewPS-ItalicMT',
      ],
    ),
    Standard14Font._(
      'Courier-BoldOblique',
      'Courier-BoldOblique.afm',
      aliases: <String>[
        'CourierNew,BoldItalic',
        'CourierNew-BoldItalic',
        'CourierNewPS-BoldItalicMT',
      ],
    ),
    Standard14Font._(
      'Helvetica',
      'Helvetica.afm',
      aliases: <String>[
        'Arial',
        'ArialMT',
        'HelveticaNeue',
      ],
    ),
    Standard14Font._(
      'Helvetica-Bold',
      'Helvetica-Bold.afm',
      aliases: <String>[
        'Arial,Bold',
        'Arial-BoldMT',
      ],
    ),
    Standard14Font._(
      'Helvetica-Oblique',
      'Helvetica-Oblique.afm',
      aliases: <String>[
        'Arial,Italic',
        'Arial-ItalicMT',
      ],
    ),
    Standard14Font._(
      'Helvetica-BoldOblique',
      'Helvetica-BoldOblique.afm',
      aliases: <String>[
        'Arial,BoldItalic',
        'Arial-BoldItalicMT',
      ],
    ),
    Standard14Font._(
      'Times-Roman',
      'Times-Roman.afm',
      aliases: <String>[
        'TimesNewRoman',
        'Times',
        'TimesNewRomanPSMT',
      ],
    ),
    Standard14Font._(
      'Times-Bold',
      'Times-Bold.afm',
      aliases: <String>[
        'TimesNewRoman,Bold',
        'Times,Bold',
        'TimesNewRomanPS-BoldMT',
      ],
    ),
    Standard14Font._(
      'Times-Italic',
      'Times-Italic.afm',
      aliases: <String>[
        'TimesNewRoman,Italic',
        'Times,Italic',
        'TimesNewRomanPS-ItalicMT',
      ],
    ),
    Standard14Font._(
      'Times-BoldItalic',
      'Times-BoldItalic.afm',
      aliases: <String>[
        'TimesNewRoman,BoldItalic',
        'Times,BoldItalic',
        'TimesNewRomanPS-BoldItalicMT',
      ],
    ),
    Standard14Font._(
      'Symbol',
      'Symbol.afm',
      aliases: <String>[
        'SymbolMT',
        'Symbol,Italic',
        'Symbol,Bold',
        'Symbol,BoldItalic',
      ],
    ),
    Standard14Font._(
      'ZapfDingbats',
      'ZapfDingbats.afm',
      aliases: <String>[
        'ITCZapfDingbats',
        'ZapfDingbatsITC',
      ],
    ),
  ];

  static final Map<String, Standard14Font> _fontByName = _buildFontMap();

  static Map<String, Standard14Font> _buildFontMap() {
    final map = <String, Standard14Font>{};
    for (final font in _fonts) {
      map[font.postScriptName] = font;
      for (final alias in font.aliases) {
        map[alias] = font;
      }
    }
    return map;
  }

  static bool contains(String? name) {
    if (name == null) {
      return false;
    }
    return _fontByName.containsKey(name);
  }

  static Standard14Font? byPostScriptName(String? name) {
    if (name == null) {
      return null;
    }
    return _fontByName[name];
  }

  static Iterable<String> get names => _fontByName.keys;
}

import 'package:logging/logging.dart';

import '../../../fontbox/font_box_font.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import 'cid_font_mapping.dart';
import 'file_system_font_info.dart';
import 'file_system_font_provider.dart';
import 'font_cache.dart';
import 'font_format.dart';
import 'font_info.dart';
import 'font_mapper.dart';
import 'font_mapping.dart';
import 'font_provider.dart';
import 'pd_cid_system_info.dart';
import 'pd_font_descriptor.dart';
import 'standard14_fonts.dart';
import 'true_type_font_box_adapter.dart';

/// Default [FontMapper] implementation that mirrors PDFBox behaviour.
class FontMapperImpl implements FontMapper {
  FontMapperImpl({
    FontProvider? provider,
    FontCache? cache,
    Logger? logger,
  })  : _logger = logger ?? Logger('pdfbox.FontMapperImpl'),
        _fontCache = cache ?? FontCache() {
    _initialiseSubstitutions();
    if (provider != null) {
      setProvider(provider);
    }
  }

  final Logger _logger;
  final FontCache _fontCache;
  FontProvider? _fontProvider;
  Map<String, FontInfo>? _fontInfoByName;
  final Map<String, List<String>> _substitutes = <String, List<String>>{};

  void setProvider(FontProvider provider) {
    _fontProvider = provider;
    _fontInfoByName = _createFontInfoIndex(provider.getFontInfo());
  }

  FontProvider getProvider() {
    if (_fontProvider == null) {
      _fontProvider = FileSystemFontProvider(cache: _fontCache, logger: _logger);
      _fontInfoByName = _createFontInfoIndex(_fontProvider!.getFontInfo());
    }
    return _fontProvider!;
  }

  void _ensureIndex() {
    if (_fontInfoByName == null) {
      setProvider(getProvider());
    }
  }

  Map<String, FontInfo> _createFontInfoIndex(List<FontInfo> fontInfo) {
    final map = <String, FontInfo>{};
    for (final info in fontInfo) {
      final names = <String>{
        info.postScriptName,
        info.postScriptName.replaceAll('-', ''),
        info.postScriptName.replaceAll(' ', ''),
      };
      for (final name in names) {
        map[_normalize(name)] = info;
      }
    }
    return map;
  }

  FontInfo? _lookupFontInfo(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    _ensureIndex();
    return _fontInfoByName![_normalize(name)];
  }

  FontInfo? _findMatchingFont(
    String name, {
    FontFormat? preferredFormat,
  }) {
    final candidate = _lookupFontInfo(name);
    if (candidate != null && _matchesFormat(candidate, preferredFormat)) {
      return candidate;
    }
    for (final substitute in _getSubstitutes(name)) {
      final info = _lookupFontInfo(substitute);
      if (info != null && _matchesFormat(info, preferredFormat)) {
        return info;
      }
    }
    return null;
  }

  bool _matchesFormat(FontInfo info, FontFormat? preferredFormat) {
    if (preferredFormat == null) {
      return true;
    }
    if (preferredFormat == FontFormat.ttf) {
      return info.format == FontFormat.ttf || info.format == FontFormat.otf;
    }
    return info.format == preferredFormat;
  }

  String _normalize(String name) => name.replaceAll('-', '').replaceAll(' ', '').toLowerCase();

  List<String> _getSubstitutes(String name) {
    final normalized = _normalize(name);
    return _substitutes[normalized] ?? const <String>[];
  }

  @override
  FontMapping<TrueTypeFont> getTrueTypeFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
  ) {
    final info = _findMatchingFont(baseFont, preferredFormat: FontFormat.ttf);
    if (info is FileSystemFontInfo) {
      try {
        return FontMapping<TrueTypeFont>(info.loadTrueTypeFont(), isFallback: false);
      } catch (error, stackTrace) {
        _logger.warning('Failed to load TrueType font "$baseFont"', error, stackTrace);
      }
    }

    final fallbackName = _getFallbackFontName(fontDescriptor);
    final fallbackInfo = _findMatchingFont(fallbackName, preferredFormat: FontFormat.ttf);
    if (fallbackInfo is FileSystemFontInfo) {
      try {
        return FontMapping<TrueTypeFont>(
          fallbackInfo.loadTrueTypeFont(),
          isFallback: true,
        );
      } catch (error, stackTrace) {
        _logger.warning('Failed to load fallback TrueType font "$fallbackName"', error, stackTrace);
      }
    }

    _logger.warning('Returning empty TrueType mapping for "$baseFont"');
    return FontMapping<TrueTypeFont>(null, isFallback: true);
  }

  @override
  FontMapping<FontBoxFont> getFontBoxFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
  ) {
    final info = _findMatchingFont(baseFont);
    if (info != null) {
      try {
        return FontMapping<FontBoxFont>(info.getFont(), isFallback: false);
      } catch (error, stackTrace) {
        _logger.warning('Failed to load FontBox font "$baseFont"', error, stackTrace);
      }
    }

    final fallback = _getFallbackFontName(fontDescriptor);
    final fallbackInfo = _findMatchingFont(fallback);
    if (fallbackInfo != null) {
      try {
        return FontMapping<FontBoxFont>(fallbackInfo.getFont(), isFallback: true);
      } catch (error, stackTrace) {
        _logger.warning('Failed to load fallback FontBox font "$fallback"', error, stackTrace);
      }
    }

    _logger.warning('Returning empty FontBox mapping for "$baseFont"');
    return FontMapping<FontBoxFont>(null, isFallback: true);
  }

  @override
  CidFontMapping getCidFont(
    String baseFont,
    PDFontDescriptor? fontDescriptor,
    PDCIDSystemInfo? cidSystemInfo,
  ) {
    final info = _findMatchingFont(baseFont, preferredFormat: FontFormat.otf);
    if (info is FileSystemFontInfo) {
      try {
        final otf = info.loadOpenTypeFont();
        if (otf != null) {
          return CidFontMapping(otf, info.getFont(), isFallback: false);
        }
      } catch (error, stackTrace) {
        _logger.warning('Failed to load CID font "$baseFont"', error, stackTrace);
      }
    }

    final mapping = getTrueTypeFont(baseFont, fontDescriptor);
    return CidFontMapping(
      null,
      mapping.font != null ? TrueTypeFontBoxAdapter(mapping.font!) : null,
      isFallback: mapping.isFallback,
    );
  }

  String _getFallbackFontName(PDFontDescriptor? descriptor) {
    final name = descriptor?.fontName;
    if (name != null) {
      final lower = name.toLowerCase();
      if (lower.contains('courier')) {
        return 'Courier';
      }
      if (lower.contains('times')) {
        return 'Times-Roman';
      }
      if (lower.contains('symbol')) {
        return 'Symbol';
      }
      if (lower.contains('dingbat')) {
        return 'ZapfDingbats';
      }
    }
    return 'Helvetica';
  }

  void _initialiseSubstitutions() {
    void add(String match, List<String> replacements) {
      _substitutes[_normalize(match)] = replacements;
    }

    add('Courier', <String>['CourierNew', 'CourierNewPSMT', 'LiberationMono', 'NimbusMonL-Regu']);
    add('Courier-Bold', <String>['CourierNewPS-BoldMT', 'CourierNew-Bold', 'LiberationMono-Bold', 'NimbusMonL-Bold']);
    add('Courier-Oblique', <String>['CourierNewPS-ItalicMT', 'CourierNew-Italic', 'LiberationMono-Italic', 'NimbusMonL-ReguObli']);
    add('Courier-BoldOblique', <String>['CourierNewPS-BoldItalicMT', 'CourierNew-BoldItalic', 'LiberationMono-BoldItalic', 'NimbusMonL-BoldObli']);
    add('Helvetica', <String>['ArialMT', 'Arial', 'LiberationSans', 'NimbusSanL-Regu']);
    add('Helvetica-Bold', <String>['Arial-BoldMT', 'Arial-Bold', 'LiberationSans-Bold', 'NimbusSanL-Bold']);
    add('Helvetica-Oblique', <String>['Arial-ItalicMT', 'Arial-Italic', 'LiberationSans-Italic', 'NimbusSanL-ReguItal']);
    add('Helvetica-BoldOblique', <String>['Arial-BoldItalicMT', 'Helvetica-BoldItalic', 'LiberationSans-BoldItalic', 'NimbusSanL-BoldItal']);
    add('Times-Roman', <String>['TimesNewRomanPSMT', 'TimesNewRoman', 'LiberationSerif', 'NimbusRomNo9L-Regu']);
    add('Times-Bold', <String>['TimesNewRomanPS-BoldMT', 'TimesNewRoman-Bold', 'LiberationSerif-Bold', 'NimbusRomNo9L-Medi']);
    add('Times-Italic', <String>['TimesNewRomanPS-ItalicMT', 'TimesNewRoman-Italic', 'LiberationSerif-Italic', 'NimbusRomNo9L-ReguItal']);
    add('Times-BoldItalic', <String>['TimesNewRomanPS-BoldItalicMT', 'TimesNewRoman-BoldItalic', 'LiberationSerif-BoldItalic', 'NimbusRomNo9L-MediItal']);
    add('Symbol', <String>['SymbolMT', 'StandardSymL']);
    add('ZapfDingbats', <String>['ZapfDingbatsITC', 'Dingbats']);

    for (final font in Standard14Fonts.names) {
      final canonical = Standard14Fonts.byPostScriptName(font);
      if (canonical == null) {
        continue;
      }
      final substitutes = _substitutes[_normalize(canonical.postScriptName)];
      if (substitutes == null) {
        continue;
      }
      for (final alias in canonical.aliases) {
        _substitutes[_normalize(alias)] = substitutes;
      }
    }
  }
}

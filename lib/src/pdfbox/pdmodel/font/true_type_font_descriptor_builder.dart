import '../../../fontbox/ttf/header_table.dart';
import '../../../fontbox/ttf/horizontal_header_table.dart';
import '../../../fontbox/ttf/os2_windows_metrics_table.dart';
import '../../../fontbox/ttf/post_script_table.dart';
import '../../../fontbox/ttf/true_type_font.dart';
import 'pd_font_descriptor.dart';

/// Utility responsible for translating TrueType metrics into a PDF font descriptor.
class TrueTypeFontDescriptorBuilder {
  TrueTypeFontDescriptorBuilder({
    required this.font,
    required this.postScriptName,
    required this.missingWidth,
  }) : _unitsPerEmScale = _computeScale(font);

  final TrueTypeFont font;
  final String postScriptName;
  final double missingWidth;

  final double _unitsPerEmScale;

  PDFontDescriptor build() {
    final descriptor = PDFontDescriptor.create(postScriptName);
    final header = font.getHeaderTable();
    final hhea = font.getHorizontalHeaderTable();
    final os2 = font.getOs2WindowsMetricsTable();
    final post = font.getPostScriptTable();
    final naming = font.getNamingTable();

    descriptor.fontFamily = naming?.getFontFamily();
    descriptor.fontStretch = _mapWidthClassToStretch(os2?.widthClass);

    final weightClass = os2?.weightClass ?? 0;
    if (weightClass > 0) {
      descriptor.fontWeight = weightClass;
    }

    descriptor.fontBBox = _buildFontBBox(header);
    descriptor.flags = _deriveFlags(os2, post, header);
    descriptor.italicAngle = post?.italicAngle ?? 0;

    final ascent = _resolveAscent(os2, hhea);
    final descent = _resolveDescent(os2, hhea);
    descriptor.ascent = ascent;
    descriptor.descent = descent;

    descriptor.leading = _scaleMetric(os2?.typoLineGap ?? hhea?.lineGap ?? 0);
  final capHeight = _resolveCapHeight(os2, ascent);
  descriptor.capHeight = capHeight;
  descriptor.xHeight = _resolveXHeight(os2, capHeight);

    final stemV = _estimateStemV(weightClass);
    if (stemV > 0) {
      descriptor.stemV = stemV;
      descriptor.stemH = stemV * 0.8;
    }

    final averageWidth = _scaleMetric(os2?.averageCharWidth ?? 0);
    if (averageWidth != 0) {
      descriptor.avgWidth = averageWidth;
    }

    final maxWidth = _scaleMetric(hhea?.advanceWidthMax ?? 0);
    if (maxWidth != 0) {
      descriptor.maxWidth = maxWidth;
    }

    descriptor.missingWidth = missingWidth;
    return descriptor;
  }

  List<double> _buildFontBBox(HeaderTable? header) {
    final bbox = <double>[0, 0, 0, 0];
    if (header != null) {
      bbox[0] = _scaleMetric(header.xMin);
      bbox[1] = _scaleMetric(header.yMin);
      bbox[2] = _scaleMetric(header.xMax);
      bbox[3] = _scaleMetric(header.yMax);
    }
    return bbox;
  }

  double _scaleMetric(num? value) {
    if (value == null) {
      return 0;
    }
    return value.toDouble() * _unitsPerEmScale;
  }

  double _resolveAscent(Os2WindowsMetricsTable? os2, HorizontalHeaderTable? hhea) {
    final raw = os2?.typoAscender ?? hhea?.ascender ?? 0;
    return _scaleMetric(raw);
  }

  double _resolveDescent(Os2WindowsMetricsTable? os2, HorizontalHeaderTable? hhea) {
    final raw = os2?.typoDescender ?? hhea?.descender ?? 0;
    return _scaleMetric(raw);
  }

  double _resolveCapHeight(Os2WindowsMetricsTable? os2, double fallback) {
    final raw = os2?.capHeight ?? 0;
    if (raw != 0) {
      return _scaleMetric(raw);
    }
    return fallback;
  }

  double _resolveXHeight(Os2WindowsMetricsTable? os2, double fallback) {
    final raw = os2?.height ?? 0;
    if (raw != 0) {
      return _scaleMetric(raw);
    }
    return fallback;
  }

  int _deriveFlags(
    Os2WindowsMetricsTable? os2,
    PostScriptTable? post,
    HeaderTable? header,
  ) {
    var flags = 0;
    if ((post?.isFixedPitch ?? 0) != 0) {
      flags |= 1;
    }

    final familyClass = os2?.familyClass ?? 0;
    final majorClass = (familyClass & 0xff00) >> 8;
    switch (majorClass) {
      case Os2WindowsMetricsTable.familyClassOldstyleSerifs:
      case Os2WindowsMetricsTable.familyClassTransitionalSerifs:
      case Os2WindowsMetricsTable.familyClassModernSerifs:
      case Os2WindowsMetricsTable.familyClassClaredonSerifs:
      case Os2WindowsMetricsTable.familyClassSlabSerifs:
      case Os2WindowsMetricsTable.familyClassFreeformSerifs:
        flags |= 2;
        break;
      case Os2WindowsMetricsTable.familyClassScripts:
        flags |= 8;
        break;
    }

    if (_isItalic(os2, post, header)) {
      flags |= 32;
    }

    if (_isSymbolicFont(os2)) {
      flags |= 4;
    } else {
      flags |= 16;
    }

    return flags;
  }

  bool _isItalic(
    Os2WindowsMetricsTable? os2,
    PostScriptTable? post,
    HeaderTable? header,
  ) {
    if (post != null && post.italicAngle != 0) {
      return true;
    }
    final selection = os2?.fsSelection ?? 0;
    if ((selection & 0x01) != 0) {
      return true;
    }
    final macStyle = header?.macStyle ?? 0;
    if ((macStyle & HeaderTable.macStyleItalic) != 0) {
      return true;
    }
    return false;
  }

  bool _isSymbolicFont(Os2WindowsMetricsTable? os2) {
    if (os2 == null) {
      return false;
    }
  final panose = os2.panose;
  if (panose.isEmpty) {
      return false;
    }
    return panose[0] == 0 && panose[1] == 0;
  }

  String? _mapWidthClassToStretch(int? widthClass) {
    switch (widthClass) {
      case Os2WindowsMetricsTable.widthClassUltraCondensed:
        return 'UltraCondensed';
      case Os2WindowsMetricsTable.widthClassExtraCondensed:
        return 'ExtraCondensed';
      case Os2WindowsMetricsTable.widthClassCondensed:
        return 'Condensed';
      case Os2WindowsMetricsTable.widthClassSemiCondensed:
        return 'SemiCondensed';
      case Os2WindowsMetricsTable.widthClassMedium:
        return 'Normal';
      case Os2WindowsMetricsTable.widthClassSemiExpanded:
        return 'SemiExpanded';
      case Os2WindowsMetricsTable.widthClassExpanded:
        return 'Expanded';
      case Os2WindowsMetricsTable.widthClassExtraExpanded:
        return 'ExtraExpanded';
      case Os2WindowsMetricsTable.widthClassUltraExpanded:
        return 'UltraExpanded';
      default:
        return null;
    }
  }

  double _estimateStemV(int weightClass) {
    if (weightClass <= 0) {
      return 0;
    }
    if (weightClass < 250) {
      return 50;
    }
    if (weightClass < 350) {
      return 70;
    }
    if (weightClass < 450) {
      return 90;
    }
    if (weightClass < 550) {
      return 110;
    }
    if (weightClass < 650) {
      return 130;
    }
    if (weightClass < 750) {
      return 150;
    }
    if (weightClass < 850) {
      return 170;
    }
    return 190;
  }

  static double _computeScale(TrueTypeFont font) {
    final unitsPerEm = font.unitsPerEm;
    if (unitsPerEm <= 0) {
      return 1;
    }
    return 1000 / unitsPerEm;
  }
}

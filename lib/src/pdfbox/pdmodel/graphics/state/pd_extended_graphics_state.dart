import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../graphics/pdf_font_setting.dart';
import '../../graphics/pd_line_dash_pattern.dart';
import '../blend/blend_mode.dart';
import 'pd_graphics_state.dart';
import 'pd_soft_mask.dart';
import 'rendering_intent.dart';

/// Extended graphics state dictionary handling.
class PDExtendedGraphicsState implements COSObjectable {
  PDExtendedGraphicsState([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  /// Applies the overrides from this extended graphics state to [state].
  void copyIntoGraphicsState(PDGraphicsState state) {
    for (final entry in _dictionary.entries) {
      final key = entry.key;
      if (key == COSName.lw) {
        final value = getLineWidth();
        if (value != null) {
          state.lineWidth = value;
        }
      } else if (key == COSName.lc) {
        final value = getLineCapStyle();
        if (value != null) {
          state.lineCap = value;
        }
      } else if (key == COSName.lj) {
        final value = getLineJoinStyle();
        if (value != null) {
          state.lineJoin = value;
        }
      } else if (key == COSName.ml) {
        final value = getMiterLimit();
        if (value != null) {
          state.miterLimit = value;
        }
      } else if (key == COSName.d) {
        final pattern = getLineDashPattern();
        if (pattern != null) {
          state.setLineDashPattern(pattern);
        }
      } else if (key == COSName.ri) {
        state.setRenderingIntent(getRenderingIntent());
      } else if (key == COSName.opm) {
        final mode = getOverprintMode();
        if (mode != null) {
          state.overprintMode = mode;
        }
      } else if (key == COSName.op) {
        state.overprint = getStrokingOverprintControl();
      } else if (key == COSName.opNs) {
        state.nonStrokingOverprint = getNonStrokingOverprintControl();
      } else if (key == COSName.font) {
        final setting = getFontSetting();
        if (setting != null) {
          state.textState.font = setting.font;
          state.textState.fontSize = setting.fontSize;
        }
      } else if (key == COSName.fl) {
        final flatness = getFlatnessTolerance();
        if (flatness != null) {
          state.flatness = flatness;
        }
      } else if (key == COSName.sm) {
        final smooth = getSmoothnessTolerance();
        if (smooth != null) {
          state.smoothness = smooth;
        }
      } else if (key == COSName.sa) {
        state.strokeAdjustment = getAutomaticStrokeAdjustment();
      } else if (key == COSName.ca) {
        final alpha = getStrokingAlphaConstant();
        if (alpha != null) {
          state.alphaConstant = alpha;
        }
      } else if (key == COSName.caNs) {
        final alpha = getNonStrokingAlphaConstant();
        if (alpha != null) {
          state.nonStrokingAlphaConstant = alpha;
        }
      } else if (key == COSName.ais) {
        state.alphaSource = getAlphaSourceFlag();
      } else if (key == COSName.tk) {
        state.textState.setKnockoutFlag(getTextKnockoutFlag());
      } else if (key == COSName.sMask) {
        final mask = getSoftMask();
        if (mask != null) {
          mask.setInitialTransformationMatrix(
            state.currentTransformationMatrix,
          );
        }
        state.setSoftMask(mask);
      } else if (key == COSName.bm) {
        state.blendMode = getBlendMode();
      } else if (key == COSName.tr || key == COSName.tr2) {
        state.transfer = getTransfer2() ?? getTransfer();
      }
    }
  }

  double? getLineWidth() => _dictionary.getFloat(COSName.lw);

  int? getLineCapStyle() => _dictionary.getInt(COSName.lc);

  int? getLineJoinStyle() => _dictionary.getInt(COSName.lj);

  double? getMiterLimit() => _dictionary.getFloat(COSName.ml);

  PDLineDashPattern? getLineDashPattern() {
    final array = _dictionary.getCOSArray(COSName.d);
    if (array == null || array.length != 2) {
      return null;
    }
    final dashArray = array.getObject(0);
    final phase = array.getObject(1);
    if (dashArray is COSArray && phase is COSNumber) {
      return PDLineDashPattern.fromCOSArray(dashArray, phase.intValue);
    }
    return null;
  }

  RenderingIntent? getRenderingIntent() {
    final name = _dictionary.getNameAsString(COSName.ri);
    return name != null ? RenderingIntent.fromString(name) : null;
  }

  bool getAutomaticStrokeAdjustment() =>
      _dictionary.getBoolean(COSName.sa) ?? false;

  double? getStrokingAlphaConstant() => _dictionary.getFloat(COSName.ca);

  double? getNonStrokingAlphaConstant() =>
      _dictionary.getFloat(COSName.caNs);

  bool getAlphaSourceFlag() => _dictionary.getBoolean(COSName.ais) ?? false;

  bool getTextKnockoutFlag() => _dictionary.getBoolean(COSName.tk) ?? true;

  double? getFlatnessTolerance() => _dictionary.getFloat(COSName.fl);

  double? getSmoothnessTolerance() => _dictionary.getFloat(COSName.sm);

  bool getStrokingOverprintControl() =>
      _dictionary.getBoolean(COSName.op) ?? false;

  bool getNonStrokingOverprintControl() =>
      _dictionary.getBoolean(COSName.opNs, getStrokingOverprintControl()) ??
      getStrokingOverprintControl();

  int? getOverprintMode() => _dictionary.getInt(COSName.opm);

  PDFontSetting? getFontSetting() {
    final value = _dictionary.getCOSArray(COSName.font);
    return value != null ? PDFontSetting(value) : null;
  }

  PDSoftMask? getSoftMask() =>
      PDSoftMask.create(_dictionary.getDictionaryObject(COSName.sMask));

  BlendMode getBlendMode() =>
      BlendMode.fromCOSBase(_dictionary.getDictionaryObject(COSName.bm));

  COSBase? getTransfer() => _dictionary.getDictionaryObject(COSName.tr);

  COSBase? getTransfer2() => _dictionary.getDictionaryObject(COSName.tr2);

}

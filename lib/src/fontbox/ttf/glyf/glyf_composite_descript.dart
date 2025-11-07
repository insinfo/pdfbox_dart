import 'package:logging/logging.dart';

import '../../io/ttf_data_stream.dart';
import '../glyph_table.dart';
import 'glyph_description.dart';
import 'glyf_composite_comp.dart';
import 'glyf_descript.dart';

/// Glyph description representing a composite glyph assembled from other glyphs.
class GlyfCompositeDescript extends GlyfDescript {
  GlyfCompositeDescript(TtfDataStream data, this._glyphTable, int level)
      : _components = <GlyfCompositeComp>[],
        _descriptions = <int, GlyphDescription>{},
        super(-1) {
    var component = GlyfCompositeComp(data);
    _components.add(component);
    while ((component.flags & GlyfCompositeComp.MORE_COMPONENTS) != 0) {
      component = GlyfCompositeComp(data);
      _components.add(component);
    }

    if ((component.flags & GlyfCompositeComp.WE_HAVE_INSTRUCTIONS) != 0) {
      final instructionCount = data.readUnsignedShort();
      readInstructions(data, instructionCount);
    }

    _initialiseDescriptions(level);
  }

  static final Logger _log = Logger('fontbox.GlyfCompositeDescript');

  final GlyphTable _glyphTable;
  final List<GlyfCompositeComp> _components;
  final Map<int, GlyphDescription> _descriptions;

  bool _beingResolved = false;
  bool _resolved = false;
  int _pointCount = -1;
  int _contourCount = -1;

  List<GlyfCompositeComp> get components =>
      List<GlyfCompositeComp>.unmodifiable(_components);

  void _initialiseDescriptions(int level) {
    for (final component in _components) {
      try {
        final glyph = _glyphTable.getGlyph(component.glyphIndex, level);
        final description = glyph?.description;
        if (description != null) {
          _descriptions[component.glyphIndex] = description;
        }
      } catch (e, stackTrace) {
        _log.severe('Failed to resolve glyph index ${component.glyphIndex}', e,
            stackTrace);
      }
    }
  }

  @override
  void resolve() {
    if (_resolved) {
      return;
    }
    if (_beingResolved) {
      _log.severe('Circular reference detected in composite glyph');
      return;
    }
    _beingResolved = true;

    var firstIndex = 0;
    var firstContour = 0;
    for (final component in _components) {
      component.setFirstIndex(firstIndex);
      component.setFirstContour(firstContour);

      final description = _descriptions[component.glyphIndex];
      if (description != null) {
        description.resolve();
        firstIndex += description.pointCount;
        firstContour += description.contourCount;
      }
    }

    _resolved = true;
    _beingResolved = false;
  }

  @override
  int getEndPtOfContours(int contourIndex) {
    final component = _findComponentForContour(contourIndex);
    if (component == null) {
      return 0;
    }
    final description = _descriptions[component.glyphIndex];
    if (description == null) {
      return 0;
    }
    final relativeIndex = contourIndex - component.firstContour;
    return description.getEndPtOfContours(relativeIndex) + component.firstIndex;
  }

  @override
  int getFlags(int pointIndex) {
    final component = _findComponentForPoint(pointIndex);
    if (component == null) {
      return 0;
    }
    final description = _descriptions[component.glyphIndex];
    if (description == null) {
      return 0;
    }
    final relativeIndex = pointIndex - component.firstIndex;
    return description.getFlags(relativeIndex);
  }

  @override
  int getXCoordinate(int pointIndex) {
    final component = _findComponentForPoint(pointIndex);
    if (component == null) {
      return 0;
    }
    final description = _descriptions[component.glyphIndex];
    if (description == null) {
      return 0;
    }
    final relativeIndex = pointIndex - component.firstIndex;
    final x = description.getXCoordinate(relativeIndex);
    final y = description.getYCoordinate(relativeIndex);
    return component.scaleX(x, y) + component.xTranslate;
  }

  @override
  int getYCoordinate(int pointIndex) {
    final component = _findComponentForPoint(pointIndex);
    if (component == null) {
      return 0;
    }
    final description = _descriptions[component.glyphIndex];
    if (description == null) {
      return 0;
    }
    final relativeIndex = pointIndex - component.firstIndex;
    final x = description.getXCoordinate(relativeIndex);
    final y = description.getYCoordinate(relativeIndex);
    return component.scaleY(x, y) + component.yTranslate;
  }

  @override
  bool get isComposite => true;

  @override
  int get pointCount {
    if (!_resolved) {
      _log.severe('pointCount requested before resolve()');
    }
    if (_pointCount >= 0) {
      return _pointCount;
    }
    final last = _components.isNotEmpty ? _components.last : null;
    final description = last != null ? _descriptions[last.glyphIndex] : null;
    if (last == null || description == null) {
      _pointCount = 0;
    } else {
      _pointCount = last.firstIndex + description.pointCount;
    }
    return _pointCount;
  }

  @override
  int get contourCount {
    if (!_resolved) {
      _log.severe('contourCount requested before resolve()');
    }
    if (_contourCount >= 0) {
      return _contourCount;
    }
    final last = _components.isNotEmpty ? _components.last : null;
    final description = last != null ? _descriptions[last.glyphIndex] : null;
    if (last == null || description == null) {
      _contourCount = 0;
    } else {
      _contourCount = last.firstContour + description.contourCount;
    }
    return _contourCount;
  }

  GlyfCompositeComp? _findComponentForPoint(int pointIndex) {
    for (final component in _components) {
      final description = _descriptions[component.glyphIndex];
      if (description == null) {
        continue;
      }
      final start = component.firstIndex;
      final end = start + description.pointCount;
      if (pointIndex >= start && pointIndex < end) {
        return component;
      }
    }
    return null;
  }

  GlyfCompositeComp? _findComponentForContour(int contourIndex) {
    for (final component in _components) {
      final description = _descriptions[component.glyphIndex];
      if (description == null) {
        continue;
      }
      final start = component.firstContour;
      final end = start + description.contourCount;
      if (contourIndex >= start && contourIndex < end) {
        return component;
      }
    }
    return null;
  }
}

import 'dart:collection';

import '../cos/cos_base.dart';
import '../cos/cos_object.dart';
import 'documentinterchange/markedcontent/pd_property_list.dart';
import 'graphics/pattern/pd_abstract_pattern.dart';
import 'graphics/pdxobject.dart';
import 'graphics/shading/pd_shading.dart';
import 'graphics/state/pd_extended_graphics_state.dart';

/// Caches high-level PDModel wrappers for shared resources.
class ResourceCache {
  ResourceCache();

  final Map<Object, PDXObject> _xObjectCache = HashMap<Object, PDXObject>();
  final Map<Object, PDShading> _shadingCache = HashMap<Object, PDShading>();
  final Map<Object, PDAbstractPattern> _patternCache =
      HashMap<Object, PDAbstractPattern>();
  final Map<Object, PDPropertyList> _propertyListCache =
      HashMap<Object, PDPropertyList>();
    final Map<Object, PDExtendedGraphicsState> _extGStateCache =
      HashMap<Object, PDExtendedGraphicsState>();

  PDXObject? getXObject(COSBase key) => _xObjectCache[_cacheKey(key)];

  void putXObject(COSBase key, PDXObject value) {
    _xObjectCache[_cacheKey(key)] = value;
  }

  PDShading? getShading(COSBase key) => _shadingCache[_cacheKey(key)];

  void putShading(COSBase key, PDShading value) {
    _shadingCache[_cacheKey(key)] = value;
  }

  PDAbstractPattern? getPattern(COSBase key) => _patternCache[_cacheKey(key)];

  void putPattern(COSBase key, PDAbstractPattern value) {
    _patternCache[_cacheKey(key)] = value;
  }

  PDPropertyList? getPropertyList(COSBase key) =>
      _propertyListCache[_cacheKey(key)];

  void putPropertyList(COSBase key, PDPropertyList value) {
    _propertyListCache[_cacheKey(key)] = value;
  }

  PDExtendedGraphicsState? getExtGState(COSBase key) =>
      _extGStateCache[_cacheKey(key)];

  void putExtGState(COSBase key, PDExtendedGraphicsState value) {
    _extGStateCache[_cacheKey(key)] = value;
  }

  Object _cacheKey(COSBase base) {
    if (base is COSObject) {
      return base.key ?? base.object;
    }
    return base;
  }
}

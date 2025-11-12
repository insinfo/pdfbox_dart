part of pdfbox.pdmodel.property_list;

/// An optional content group (OCG).
class PDOptionalContentGroup extends PDPropertyList {
  PDOptionalContentGroup(String name) : super() {
    dict[COSName.type] = COSName.ocg;
    setName(name);
  }

  PDOptionalContentGroup.fromDictionary(COSDictionary dictionary)
      : super(dictionary: dictionary) {
    final type = dictionary.getDictionaryObject(COSName.type);
    if (type != COSName.ocg) {
      throw ArgumentError(
        "Provided dictionary is not of type '${COSName.ocg.name}'",
      );
    }
  }

  /// Returns the name assigned to this optional content group.
  String? get name => dict.getString(COSName.nameKey);

  /// Assigns a human-readable name to this optional content group.
  void setName(String name) {
  dict.setString(COSName.nameKey, name);
  }

  /// Resolves the usage-dependent state for [destination] if present.
  RenderState? getRenderState(RenderDestination destination) {
    COSName? state;
    final usage = dict.getCOSDictionary(COSName.usage);
    if (usage != null) {
      if (destination == RenderDestination.print) {
        final print = usage.getCOSDictionary(COSName.print);
        state = print?.getCOSName(COSName.printState);
      } else if (destination == RenderDestination.view) {
        final view = usage.getCOSDictionary(COSName.view);
        state = view?.getCOSName(COSName.viewState);
      }
      if (state == null) {
        final export = usage.getCOSDictionary(COSName.export);
        state = export?.getCOSName(COSName.exportState);
      }
    }
  return RenderState.fromCOSName(state);
  }

  @override
  String toString() => '${super.toString()} (${name ?? 'Unnamed OCG'})';
}

/// Enumerates the usage states for an optional content group.
enum RenderState {
  on('ON'),
  off('OFF');

  const RenderState(this._value);

  final String _value;

  COSName get name => COSName(_value);

  static RenderState? fromCOSName(COSName? state) {
    if (state == null) {
      return null;
    }
    if (state == COSName.on) {
      return RenderState.on;
    }
    if (state == COSName.off) {
      return RenderState.off;
    }
    return null;
  }
}

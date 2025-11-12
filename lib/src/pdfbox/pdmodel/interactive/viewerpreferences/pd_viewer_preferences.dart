import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';

/// Represents the /ViewerPreferences entry inside the document catalog.
class PDViewerPreferences implements COSObjectable {
  PDViewerPreferences([COSDictionary? dictionary])
      : _dictionary = dictionary ?? COSDictionary();

  final COSDictionary _dictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  bool get hideToolbar =>
      _dictionary.getBoolean(COSName.hideToolbar, false) ?? false;

  set hideToolbar(bool value) =>
      _dictionary.setBoolean(COSName.hideToolbar, value);

  bool get hideMenubar =>
      _dictionary.getBoolean(COSName.hideMenubar, false) ?? false;

  set hideMenubar(bool value) =>
      _dictionary.setBoolean(COSName.hideMenubar, value);

  bool get hideWindowUI =>
      _dictionary.getBoolean(COSName.hideWindowUI, false) ?? false;

  set hideWindowUI(bool value) =>
      _dictionary.setBoolean(COSName.hideWindowUI, value);

  bool get fitWindow =>
      _dictionary.getBoolean(COSName.fitWindow, false) ?? false;

  set fitWindow(bool value) =>
      _dictionary.setBoolean(COSName.fitWindow, value);

  bool get centerWindow =>
      _dictionary.getBoolean(COSName.centerWindow, false) ?? false;

  set centerWindow(bool value) =>
      _dictionary.setBoolean(COSName.centerWindow, value);

  bool get displayDocTitle =>
      _dictionary.getBoolean(COSName.displayDocTitle, false) ?? false;

  set displayDocTitle(bool value) =>
      _dictionary.setBoolean(COSName.displayDocTitle, value);

  NonFullScreenPageMode get nonFullScreenPageMode {
    final name = _dictionary.getNameAsString(
          COSName.nonFullScreenPageMode,
          NonFullScreenPageMode.useNone.pdfName,
        ) ??
        NonFullScreenPageMode.useNone.pdfName;
    return NonFullScreenPageMode.values.firstWhere(
      (mode) => mode.pdfName == name,
      orElse: () => NonFullScreenPageMode.useNone,
    );
  }

  set nonFullScreenPageMode(NonFullScreenPageMode mode) =>
      _dictionary.setName(COSName.nonFullScreenPageMode, mode.pdfName);

  ReadingDirection get direction {
    final name = _dictionary.getNameAsString(
          COSName.direction,
          ReadingDirection.l2r.pdfName,
        ) ??
        ReadingDirection.l2r.pdfName;
    return ReadingDirection.values.firstWhere(
      (entry) => entry.pdfName == name,
      orElse: () => ReadingDirection.l2r,
    );
  }

  set direction(ReadingDirection direction) =>
      _dictionary.setName(COSName.direction, direction.pdfName);

  Boundary get viewArea => _getBoundary(
        COSName.viewArea,
        Boundary.cropBox,
      );

  set viewArea(Boundary boundary) =>
      _dictionary.setName(COSName.viewArea, boundary.pdfName);

  Boundary get viewClip => _getBoundary(
        COSName.viewClip,
        Boundary.cropBox,
      );

  set viewClip(Boundary boundary) =>
      _dictionary.setName(COSName.viewClip, boundary.pdfName);

  Boundary get printArea => _getBoundary(
        COSName.printArea,
        Boundary.cropBox,
      );

  set printArea(Boundary boundary) =>
      _dictionary.setName(COSName.printArea, boundary.pdfName);

  Boundary get printClip => _getBoundary(
        COSName.printClip,
        Boundary.cropBox,
      );

  set printClip(Boundary boundary) =>
      _dictionary.setName(COSName.printClip, boundary.pdfName);

  Duplex? get duplex {
    final name = _dictionary.getNameAsString(COSName.duplex);
    if (name == null) {
      return null;
    }
    return Duplex.values.firstWhere(
      (value) => value.pdfName == name,
      orElse: () => Duplex.simplex,
    );
  }

  set duplex(Duplex? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.duplex);
      return;
    }
    _dictionary.setName(COSName.duplex, value.pdfName);
  }

  PrintScaling get printScaling {
    final name = _dictionary.getNameAsString(
          COSName.printScaling,
          PrintScaling.appDefault.pdfName,
        ) ??
        PrintScaling.appDefault.pdfName;
    return PrintScaling.values.firstWhere(
      (value) => value.pdfName == name,
      orElse: () => PrintScaling.appDefault,
    );
  }

  set printScaling(PrintScaling value) =>
      _dictionary.setName(COSName.printScaling, value.pdfName);

  Boundary _getBoundary(COSName key, Boundary defaultValue) {
    final name = _dictionary.getNameAsString(key, defaultValue.pdfName) ??
        defaultValue.pdfName;
    return Boundary.values.firstWhere(
      (boundary) => boundary.pdfName == name,
      orElse: () => defaultValue,
    );
  }
}

enum NonFullScreenPageMode {
  useNone('UseNone'),
  useOutlines('UseOutlines'),
  useThumbs('UseThumbs'),
  useOC('UseOC');

  const NonFullScreenPageMode(this.pdfName);
  final String pdfName;
}

enum ReadingDirection {
  l2r('L2R'),
  r2l('R2L');

  const ReadingDirection(this.pdfName);
  final String pdfName;
}

enum Boundary {
  mediaBox('MediaBox'),
  cropBox('CropBox'),
  bleedBox('BleedBox'),
  trimBox('TrimBox'),
  artBox('ArtBox');

  const Boundary(this.pdfName);
  final String pdfName;
}

enum Duplex {
  simplex('Simplex'),
  duplexFlipShortEdge('DuplexFlipShortEdge'),
  duplexFlipLongEdge('DuplexFlipLongEdge');

  const Duplex(this.pdfName);
  final String pdfName;
}

enum PrintScaling {
  none('None'),
  appDefault('AppDefault');

  const PrintScaling(this.pdfName);
  final String pdfName;
}

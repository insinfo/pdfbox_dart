import '../../cos/cos_base.dart' show COSBase, COSObjectable;
import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_object.dart';
import '../../cos/cos_stream.dart';
import '../../cos/cos_string.dart';
import 'pd_embedded_file.dart';

/// Represents a generic file specification wrapper.
abstract class PDFileSpecification implements COSObjectable {
  const PDFileSpecification();

  String? get file;

  set file(String? value);

  static PDFileSpecification? fromCOS(COSBase? base) {
    if (base == null) {
      return null;
    }
    if (base is COSObject) {
      return fromCOS(base.object);
    }
    if (base is COSDictionary) {
      return PDComplexFileSpecification(dictionary: base);
    }
    if (base is COSString) {
      return PDSimpleFileSpecification(base);
    }
    return null;
  }
}

/// String based file specification.
class PDSimpleFileSpecification extends PDFileSpecification {
  PDSimpleFileSpecification(this._string);

  COSString _string;

  @override
  String? get file => _string.string;

  @override
  set file(String? value) {
    _string = COSString(value ?? '');
  }

  @override
  COSString get cosObject => _string;
}

class PDComplexFileSpecification extends PDFileSpecification {
  PDComplexFileSpecification({COSDictionary? dictionary})
      : _dictionary = dictionary ?? COSDictionary() {
    if (_dictionary.getNameAsString(COSName.type) == null) {
      _dictionary[COSName.type] = COSName.filespec;
    }
  }

  final COSDictionary _dictionary;
  COSDictionary? _embeddedFilesDictionary;

  @override
  COSDictionary get cosObject => _dictionary;

  @override
  String? get file => _dictionary.getString(COSName.f);

  @override
  set file(String? value) => _dictionary.setString(COSName.f, value);

  String? get unicodeFile => _dictionary.getString(COSName.uf);

  set unicodeFile(String? value) => _dictionary.setString(COSName.uf, value);

  String? get dosFile => _dictionary.getString(COSName.dos);

  set dosFile(String? value) => _dictionary.setString(COSName.dos, value);

  String? get macFile => _dictionary.getString(COSName.mac);

  set macFile(String? value) => _dictionary.setString(COSName.mac, value);

  String? get unixFile => _dictionary.getString(COSName.unix);

  set unixFile(String? value) => _dictionary.setString(COSName.unix, value);

  bool get isVolatile => _dictionary.getBoolean(COSName.v, false) ?? false;

  set isVolatile(bool value) => _dictionary.setBoolean(COSName.v, value);

  String? get description => _dictionary.getString(COSName.desc);

  set description(String? value) => _dictionary.setString(COSName.desc, value);

  PDEmbeddedFile? get embeddedFile => _getEmbeddedFile(COSName.f);

  set embeddedFile(PDEmbeddedFile? value) => _setEmbeddedFile(COSName.f, value);

  PDEmbeddedFile? get embeddedFileUnicode => _getEmbeddedFile(COSName.uf);

  set embeddedFileUnicode(PDEmbeddedFile? value) =>
      _setEmbeddedFile(COSName.uf, value);

  PDEmbeddedFile? get embeddedFileDos => _getEmbeddedFile(COSName.dos);

  set embeddedFileDos(PDEmbeddedFile? value) =>
      _setEmbeddedFile(COSName.dos, value);

  PDEmbeddedFile? get embeddedFileMac => _getEmbeddedFile(COSName.mac);

  set embeddedFileMac(PDEmbeddedFile? value) =>
      _setEmbeddedFile(COSName.mac, value);

  PDEmbeddedFile? get embeddedFileUnix => _getEmbeddedFile(COSName.unix);

  set embeddedFileUnix(PDEmbeddedFile? value) =>
      _setEmbeddedFile(COSName.unix, value);

  COSDictionary? _getEmbeddedFilesDict() {
    _embeddedFilesDictionary ??=
        _dictionary.getCOSDictionary(COSName.ef);
    return _embeddedFilesDictionary;
  }

  COSDictionary _ensureEmbeddedFilesDict() {
    final existing = _getEmbeddedFilesDict();
    if (existing != null) {
      return existing;
    }
    final created = COSDictionary();
    _dictionary[COSName.ef] = created;
    _embeddedFilesDictionary = created;
    return created;
  }

  PDEmbeddedFile? _getEmbeddedFile(COSName key) {
    final ef = _getEmbeddedFilesDict();
    if (ef == null) {
      return null;
    }
    final base = ef.getDictionaryObject(key);
    final resolved = base is COSObject ? base.object : base;
    if (resolved is COSStream) {
      return PDEmbeddedFile(resolved);
    }
    return null;
  }

  void _setEmbeddedFile(COSName key, PDEmbeddedFile? value) {
    if (value == null) {
      final ef = _getEmbeddedFilesDict();
      ef?.removeItem(key);
      _pruneEmbeddedFilesDict(ef);
      return;
    }
    final ef = _ensureEmbeddedFilesDict();
    ef[key] = value.cosStream;
  }

  void _pruneEmbeddedFilesDict(COSDictionary? ef) {
    final current = ef ?? _getEmbeddedFilesDict();
    if (current != null && current.isEmpty) {
      _dictionary.removeItem(COSName.ef);
      _embeddedFilesDictionary = null;
    }
  }
}

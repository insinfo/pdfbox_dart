import 'dart:typed_data';

import '../../cos/cos_dictionary.dart';
import '../../cos/cos_name.dart';
import '../../cos/cos_stream.dart';
import '../pd_stream.dart';

/// Wraps an embedded file stream referenced from a file specification.
class PDEmbeddedFile extends PDStream {
  PDEmbeddedFile(COSStream stream) : super(stream) {
    cosStream[COSName.type] = COSName.embeddedFile;
  }

  factory PDEmbeddedFile.fromBytes(Uint8List data) {
    final stream = COSStream()..data = data;
    return PDEmbeddedFile(stream);
  }

  String? get subtype => cosStream.getNameAsString(COSName.subtype);

  set subtype(String? value) => cosStream.setName(COSName.subtype, value);

  int? get size => _params?.getInt(COSName.size);

  set size(int? value) => _setIntParam(COSName.size, value);

  DateTime? get creationDate => _params?.getDate(COSName.creationDate);

  set creationDate(DateTime? value) => _setDateParam(COSName.creationDate, value);

  DateTime? get modDate => _params?.getDate(COSName.modDate);

  set modDate(DateTime? value) => _setDateParam(COSName.modDate, value);

  String? get checkSum => _params?.getString(COSName.checkSum);

  set checkSum(String? value) => _setStringParam(COSName.checkSum, value);

  String? get macSubtype => _macParams?.getString(COSName.subtype);

  set macSubtype(String? value) => _setMacString(COSName.subtype, value);

  String? get macCreator => _macParams?.getString(COSName.creator);

  set macCreator(String? value) => _setMacString(COSName.creator, value);

  String? get macResFork => _macParams?.getString(COSName.resFork);

  set macResFork(String? value) => _setMacString(COSName.resFork, value);

  COSDictionary? get _params => cosStream.getCOSDictionary(COSName.params);

  COSDictionary? get _macParams => _params?.getCOSDictionary(COSName.mac);

  COSDictionary _ensureParams() {
    final existing = _params;
    if (existing != null) {
      return existing;
    }
    final created = COSDictionary();
    cosStream[COSName.params] = created;
    return created;
  }

  COSDictionary _ensureMacParams() {
    final params = _ensureParams();
    final existing = params.getCOSDictionary(COSName.mac);
    if (existing != null) {
      return existing;
    }
    final created = COSDictionary();
    params[COSName.mac] = created;
    return created;
  }

  void _setIntParam(COSName key, int? value) {
    if (value == null) {
      final params = _params;
      params?.removeItem(key);
      _pruneParamsIfEmpty(params);
      return;
    }
    final params = _ensureParams();
    params.setInt(key, value);
  }

  void _setDateParam(COSName key, DateTime? value) {
    if (value == null) {
      final params = _params;
      params?.removeItem(key);
      _pruneParamsIfEmpty(params);
      return;
    }
    final params = _ensureParams();
    params.setDate(key, value);
  }

  void _setStringParam(COSName key, String? value) {
    final params = value == null ? _params : _ensureParams();
    params?.setString(key, value);
    _pruneParamsIfEmpty(params);
  }

  void _setMacString(COSName key, String? value) {
    if (value == null) {
      final mac = _macParams;
      mac?.setString(key, null);
      _pruneMacIfEmpty(mac);
      return;
    }
    final mac = _ensureMacParams();
    mac.setString(key, value);
  }

  void _pruneParamsIfEmpty(COSDictionary? params) {
    final current = params ?? _params;
    if (current != null && current.isEmpty) {
      cosStream.removeItem(COSName.params);
    }
  }

  void _pruneMacIfEmpty(COSDictionary? mac) {
    final current = mac ?? _macParams;
    if (current != null && current.isEmpty) {
      final params = _params;
      params?.removeItem(COSName.mac);
      _pruneParamsIfEmpty(params);
    }
  }
}

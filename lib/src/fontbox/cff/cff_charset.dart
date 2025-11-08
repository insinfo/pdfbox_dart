/// Contract describing how glyph identifiers map to SIDs/CIDs in CFF fonts.
abstract class CFFCharset {
  /// Whether this charset represents a CID-keyed font.
  bool get isCIDFont;

  /// Registers a glyph/SID mapping for Type 1-equivalent fonts.
  void addSID(int gid, int sid, String name);

  /// Registers a glyph/CID mapping for CID-keyed fonts.
  void addCID(int gid, int cid);

  /// Returns the SID associated with the provided [gid], or 0 when missing.
  int getSIDForGID(int gid);

  /// Returns the GID associated with the provided [sid], or 0 when missing.
  int getGIDForSID(int sid);

  /// Returns the GID associated with the provided [cid], or 0 when missing.
  int getGIDForCID(int cid);

  /// Returns the SID associated with a PostScript [name], or 0 when missing.
  int getSID(String name);

  /// Resolves the PostScript glyph name assigned to [gid], or null when unknown.
  String? getNameForGID(int gid);

  /// Returns the CID associated with [gid], or 0 when missing.
  int getCIDForGID(int gid);
}

class _CFFCharsetType1 implements CFFCharset {
  static const String _notCidMessage = 'Not a CIDFont';

  final Map<int, int> _sidToGid = <int, int>{};
  final Map<int, int> _gidToSid = <int, int>{};
  final Map<String, int> _nameToSid = <String, int>{};
  final Map<int, String> _gidToName = <int, String>{};

  @override
  bool get isCIDFont => false;

  @override
  void addSID(int gid, int sid, String name) {
    _sidToGid[sid] = gid;
    _gidToSid[gid] = sid;
    _nameToSid[name] = sid;
    _gidToName[gid] = name;
  }

  @override
  void addCID(int gid, int cid) {
    throw StateError(_notCidMessage);
  }

  @override
  int getSIDForGID(int gid) => _gidToSid[gid] ?? 0;

  @override
  int getGIDForSID(int sid) => _sidToGid[sid] ?? 0;

  @override
  int getGIDForCID(int cid) {
    throw StateError(_notCidMessage);
  }

  @override
  int getSID(String name) => _nameToSid[name] ?? 0;

  @override
  String? getNameForGID(int gid) => _gidToName[gid];

  @override
  int getCIDForGID(int gid) {
    throw StateError(_notCidMessage);
  }
}

class _CFFCharsetCID implements CFFCharset {
  static const String _notType1Message = 'Not a Type 1-equivalent font';

  final Map<int, int> _cidToGid = <int, int>{};
  final Map<int, int> _gidToCid = <int, int>{};

  @override
  bool get isCIDFont => true;

  @override
  void addSID(int gid, int sid, String name) {
    throw StateError(_notType1Message);
  }

  @override
  void addCID(int gid, int cid) {
    _cidToGid[cid] = gid;
    _gidToCid[gid] = cid;
  }

  @override
  int getSIDForGID(int gid) {
    throw StateError(_notType1Message);
  }

  @override
  int getGIDForSID(int sid) {
    throw StateError(_notType1Message);
  }

  @override
  int getGIDForCID(int cid) => _cidToGid[cid] ?? 0;

  @override
  int getSID(String name) {
    throw StateError(_notType1Message);
  }

  @override
  String? getNameForGID(int gid) {
    throw StateError(_notType1Message);
  }

  @override
  int getCIDForGID(int gid) => _gidToCid[gid] ?? 0;
}

/// Mutable charset implementation used when glyph names/CIDs are embedded in the font.
class EmbeddedCharset implements CFFCharset {
  EmbeddedCharset({required bool isCidFont})
      : _delegate = isCidFont ? _CFFCharsetCID() : _CFFCharsetType1();

  final CFFCharset _delegate;

  @override
  bool get isCIDFont => _delegate.isCIDFont;

  @override
  void addSID(int gid, int sid, String name) => _delegate.addSID(gid, sid, name);

  @override
  void addCID(int gid, int cid) => _delegate.addCID(gid, cid);

  @override
  int getSIDForGID(int gid) => _delegate.getSIDForGID(gid);

  @override
  int getGIDForSID(int sid) => _delegate.getGIDForSID(sid);

  @override
  int getGIDForCID(int cid) => _delegate.getGIDForCID(cid);

  @override
  int getSID(String name) => _delegate.getSID(name);

  @override
  String? getNameForGID(int gid) => _delegate.getNameForGID(gid);

  @override
  int getCIDForGID(int gid) => _delegate.getCIDForGID(gid);
}


import 'dart:collection';

import '../cos/cos_base.dart' show COSObjectable;
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';

/// Represents the document information dictionary (the /Info entry).
class PDDocumentInformation implements COSObjectable {
  PDDocumentInformation({COSDictionary? dictionary})
      : _info = dictionary ?? COSDictionary();

  final COSDictionary _info;

  @override
  COSDictionary get cosObject => _info;

  /// Returns the raw string value stored under the given [key].
  String? getPropertyStringValue(String key) =>
      _info.getString(COSName(key));

  String? get title => _info.getString(COSName.title);

  set title(String? value) => _info.setString(COSName.title, value);

  String? get author => _info.getString(COSName.author);

  set author(String? value) => _info.setString(COSName.author, value);

  String? get subject => _info.getString(COSName.subject);

  set subject(String? value) => _info.setString(COSName.subject, value);

  String? get keywords => _info.getString(COSName.keywords);

  set keywords(String? value) => _info.setString(COSName.keywords, value);

  String? get creator => _info.getString(COSName.creator);

  set creator(String? value) => _info.setString(COSName.creator, value);

  String? get producer => _info.getString(COSName.producer);

  set producer(String? value) => _info.setString(COSName.producer, value);

  DateTime? get creationDate => _info.getDate(COSName.creationDate);

  set creationDate(DateTime? value) => _info.setDate(COSName.creationDate, value);

  DateTime? get modificationDate => _info.getDate(COSName.modDate);

  set modificationDate(DateTime? value) =>
      _info.setDate(COSName.modDate, value);

  String? get trapped => _info.getNameAsString(COSName.trapped);

  set trapped(String? value) {
    if (value != null &&
        value != 'True' &&
        value != 'False' &&
        value != 'Unknown') {
      throw ArgumentError(
        "Valid values for trapped are 'True', 'False', or 'Unknown'",
      );
    }
    _info.setName(COSName.trapped, value);
  }

  Set<String> get metadataKeys {
    final keys = SplayTreeSet<String>();
    for (final key in _info.keys) {
      keys.add(key.name);
    }
    return keys;
  }

  String? getCustomMetadataValue(String fieldName) =>
      _info.getString(COSName(fieldName));

  void setCustomMetadataValue(String fieldName, String? value) {
    _info.setString(COSName(fieldName), value);
  }
}

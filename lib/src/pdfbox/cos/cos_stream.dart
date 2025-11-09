import 'dart:async';
import 'dart:typed_data';

import 'cos_array.dart';
import 'cos_dictionary.dart';
import 'cos_name.dart';
import 'cos_string.dart';

class COSStream extends COSDictionary {
  COSStream();

  Uint8List? _data;

  Uint8List? get data => _data == null ? null : Uint8List.fromList(_data!);

  set data(Uint8List? value) {
    _data = value == null ? null : Uint8List.fromList(value);
    if (_data != null) {
      setInt(COSName.length, _data!.length);
    } else {
      removeItem(COSName.length);
    }
  }

  Stream<List<int>> openStream() {
    if (_data == null) {
      return const Stream<List<int>>.empty();
    }
    return Stream<List<int>>.value(Uint8List.fromList(_data!));
  }

  List<COSName> get filters {
    final raw = getDictionaryObject(COSName.filter);
    if (raw == null) {
      return const <COSName>[];
    }
    if (raw is COSName) {
      return <COSName>[raw];
    }
    if (raw is COSArray) {
      final names = <COSName>[];
      for (final entry in raw) {
        if (entry is COSName) {
          names.add(entry);
        } else if (entry is COSString) {
          names.add(COSName(entry.string));
        }
      }
      return names;
    }
    if (raw is COSString) {
      return <COSName>[COSName(raw.string)];
    }
    return const <COSName>[];
  }
}

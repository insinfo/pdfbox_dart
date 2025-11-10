import 'dart:typed_data';

import '../../../cos/cos_array.dart';
import '../../../cos/cos_base.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_integer.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';
import '../../../cos/cos_object.dart';
import '../../../cos/cos_string.dart';
import 'pd_prop_build.dart';

/// High level representation of a PDF digital signature dictionary.
class PDSignature implements COSObjectable {
  PDSignature([COSDictionary? dictionary])
      : _dictionary = dictionary ?? _createDictionary();

  static COSDictionary _createDictionary() {
    final dict = COSDictionary();
    dict[COSName.type] = COSName.sig;
    return dict;
  }

  final COSDictionary _dictionary;

  /// Common filter constants used by PDF signatures.
  static final COSName filterAdobePpklite = COSName.adobePpklite;
  static final COSName filterEntrustPpKef = COSName.entrustPpKef;
  static final COSName filterCiciSignIt = COSName.ciciSignIt;
  static final COSName filterVeriSignPpkvs = COSName.verisignPpkvs;

  /// Common sub-filter constants.
  static final COSName subFilterAdbeX509RsaSha1 = COSName.adbeX509RsaSha1;
  static final COSName subFilterAdbePkcs7Detached = COSName.adbePkcs7Detached;
  static final COSName subFilterEtsiCadesDetached = COSName.etsiCadesDetached;
  static final COSName subFilterAdbePkcs7Sha1 = COSName.adbePkcs7Sha1;

  @override
  COSDictionary get cosObject => _dictionary;

  void setType(COSName type) {
    _dictionary[COSName.type] = type;
  }

  String? get filter => _dictionary.getNameAsString(COSName.filter);

  void setFilter(COSName? filter) {
    if (filter == null) {
      _dictionary.removeItem(COSName.filter);
    } else {
      _dictionary[COSName.filter] = filter;
    }
  }

  String? get subFilter => _dictionary.getNameAsString(COSName.subFilter);

  void setSubFilter(COSName? subFilter) {
    if (subFilter == null) {
      _dictionary.removeItem(COSName.subFilter);
    } else {
      _dictionary[COSName.subFilter] = subFilter;
    }
  }

  String? get name => _dictionary.getString(COSName.nameKey);

  void setName(String? value) => _dictionary.setString(COSName.nameKey, value);

  String? get location => _dictionary.getString(COSName.location);

  void setLocation(String? value) => _dictionary.setString(COSName.location, value);

  String? get reason => _dictionary.getString(COSName.reason);

  void setReason(String? value) => _dictionary.setString(COSName.reason, value);

  String? get contactInfo => _dictionary.getString(COSName.contactInfo);

  void setContactInfo(String? value) => _dictionary.setString(COSName.contactInfo, value);

  DateTime? get signDate => _dictionary.getDate(COSName.m);

  void setSignDate(DateTime? date) => _dictionary.setDate(COSName.m, date);

  void setByteRange(List<int> range) {
    if (range.length != 4) {
      throw ArgumentError.value(range.length, 'range', 'ByteRange must have four elements');
    }
    final array = COSArray();
    for (final value in range) {
      array.addObject(COSInteger(value));
    }
    array.isDirect = true;
    _dictionary[COSName.byteRange] = array;
  }

  List<int> get byteRange {
    final array = _dictionary.getCOSArray(COSName.byteRange);
    if (array == null) {
      return const <int>[];
    }
    final values = <int>[];
    for (final element in array) {
      values.add(_resolveInt(element));
    }
    return values;
  }

  Uint8List getContents() {
    final base = _dictionary.getDictionaryObject(COSName.contents);
    if (base is COSString) {
      return base.bytes;
    }
    return Uint8List(0);
  }

  void setContents(Uint8List bytes) {
    _dictionary[COSName.contents] = COSString.fromBytes(bytes, isHex: true);
  }

  /// Returns the concatenated signed content defined by the `/ByteRange` entry.
  ///
  /// The returned bytes represent the exact data that was signed, excluding the
  /// placeholder reserved for the signature value itself.
  Uint8List getSignedContent(Uint8List pdfBytes) {
    final range = byteRange;
    if (range.length != 4) {
      throw StateError('ByteRange is not defined');
    }
    final start0 = range[0];
    final length0 = range[1];
    final start1 = range[2];
    final length1 = range[3];

    if (start0 < 0 || length0 < 0 || start1 < 0 || length1 < 0) {
      throw ArgumentError('ByteRange contains negative values: $range');
    }
    if (start0 + length0 > pdfBytes.length ||
        start1 + length1 > pdfBytes.length) {
      throw RangeError('ByteRange exceeds the provided buffer length');
    }

    final builder = BytesBuilder(copy: false);
    builder.add(pdfBytes.sublist(start0, start0 + length0));
    builder.add(pdfBytes.sublist(start1, start1 + length1));
    return builder.toBytes();
  }

  PDPropBuild? get propBuild {
    final dict = _dictionary.getCOSDictionary(COSName.propBuild);
    return dict == null ? null : PDPropBuild(dict);
  }

  void setPropBuild(PDPropBuild? value) {
    if (value == null) {
      _dictionary.removeItem(COSName.propBuild);
    } else {
      _dictionary[COSName.propBuild] = value;
    }
  }

  int _resolveInt(COSBase? base) {
    if (base is COSNumber) {
      return base.intValue;
    }
    if (base is COSObject) {
      return _resolveInt(base.object);
    }
    throw StateError('Expected number in ByteRange but found ${base.runtimeType}');
  }
}

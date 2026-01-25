import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import '../cos/cos_stream.dart';

/// Represents the DSS dictionary (Document Security Store) - implementation of PAdES LTV
class PdfDssDictionary extends COSDictionary {
  /// Initialize a new instance of [PdfDssDictionary]
  PdfDssDictionary([COSDictionary? dictionary]) {
    if (dictionary != null) {
      addAll(dictionary);
    }
  }

  /// Adds a CRL stream to the DSS
  void addCrl(List<int> crlBytes) {
    _addToArray(COSName('CRLs'), crlBytes);
  }
  
  /// Adds an OCSP stream to the DSS
  void addOcsp(List<int> ocspBytes) {
    _addToArray(COSName('OCSPs'), ocspBytes);
  }
  
  /// Adds a Certificate stream to the DSS
  void addCert(List<int> certBytes) {
    _addToArray(COSName('Certs'), certBytes);
  }
  
  void _addToArray(COSName key, List<int> data) {
    COSArray? arr = getCOSArray(key);
    if (arr == null) {
      arr = COSArray();
      this[key] = arr;
    }
    final COSStream stream = COSStream();
    stream.data = Uint8List.fromList(data);
    arr.add(stream);
  }
}


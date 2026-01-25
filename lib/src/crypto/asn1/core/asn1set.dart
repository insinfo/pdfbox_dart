part of '../asn1.dart';

///
/// An ASN1Set.
///
class ASN1Set extends ASN1Object {
  final Set<ASN1Object> elements = <ASN1Object>{};

  ///
  /// Create a set from the bytes
  ///
  /// Note that bytes could be longer than the actual sequence - in which case we would ignore any remaining bytes
  ///
  ASN1Set.fromBytes(super.bytes) : super.fromBytes() {
    if (!isSet(tag)) {
      throw ASN1Exception('The tag $tag does not look like a set type');
    }
    _decodeSet();
  }

  ASN1Set({super.tag = CONSTRUCTED_SET_TYPE});

  ///
  /// Add an element to the set
  ///
  void add(ASN1Object o) {
    elements.add(o);
    _encodedBytes = null;
  }

  @override
  Uint8List _encode() {
    _valueByteLength = _encodedLengthOfChildren(elements);
    super._encodeHeader();
    _writeEncodedChildren(elements, this);
    return _encodedBytes!;
  }

  void _decodeSet() {
    /*
      var l = ASN1Length.decodeLength(encodedBytes);
      this.valueStartPosition = l.valueStartPosition;
      this.valueByteLength = l.length;
      // now we know our value - but we need to scan for further embedded elements...
       */
    var parser = ASN1Parser(valueBytes());
    _decodeElements(parser, elements.add);
  }

  @override
  String toString() {
    var b = StringBuffer('Set[');
    for (var e in elements) {
      b.write(e.toString());
      b.write(' ');
    }
    b.write(']');
    return b.toString();
  }
}


part of '../asn1.dart';

///
/// Represents a ASN1 BER encoded sequence.
///
/// A sequence is a container for other ASN1 objects
/// Objects are serialized sequentially to the stream
///
class ASN1Sequence extends ASN1Object {
  List<ASN1Object> elements = <ASN1Object>[];

  ///
  /// Create a sequence from the byte array [super.bytes].
  ///
  /// Note that bytes array b could be longer than the actual encoded sequence - in which case
  /// we ignore any remaining bytes.
  ///
  ASN1Sequence.fromBytes(super.bytes) : super.fromBytes() {
    if (isUniversal(tag) && !isSequence(tag)) {
      throw ASN1Exception('The tag $tag does not look like a sequence type');
    }
    _decodeSeq();
  }

  ///
  /// Create a new empty ASN1 Sequence. Optionally override the default tag
  ///
  ASN1Sequence({super.tag = CONSTRUCTED_SEQUENCE_TYPE});

  ///
  /// Add an [ASN1Object] to the sequence. Objects will be serialized to BER in the order they were added
  ///
  void add(ASN1Object o) {
    elements.add(o);
    _encodedBytes = null; // fixes #73. Make sure to reset any previous encoding
  }

  @override
  Uint8List _encode() {
    _valueByteLength = _encodedLengthOfChildren(elements);
    super._encodeHeader();
    _writeEncodedChildren(elements, this);
    return _encodedBytes!;
  }

  void _decodeSeq() {
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
    var b = StringBuffer('Seq[');
    for (var e in elements) {
      b.write(e.toString());
      b.write(' ');
    }
    b.write(']');
    return b.toString();
  }
}

int _encodedLengthOfChildren(Iterable<ASN1Object> children) {
  var length = 0;
  for (final child in children) {
    length += child._encode().length;
  }
  return length;
}

void _writeEncodedChildren(Iterable<ASN1Object> children, ASN1Object target) {
  var offset = target._valueStartPosition;
  for (final child in children) {
    final bytes = child.encodedBytes;
    target.encodedBytes.setRange(offset, offset + bytes.length, bytes);
    offset += bytes.length;
  }
}

void _decodeElements(ASN1Parser parser, void Function(ASN1Object) addElement) {
  while (parser.hasNext()) {
    addElement(parser.nextObject());
  }
}


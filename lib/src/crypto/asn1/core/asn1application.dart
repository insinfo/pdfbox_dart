part of '../asn1.dart';

// Represent an ASN1 APPLICATION type. An Application is a
// custom ASN1 object that delegates the interpretation to the
// consumer.
class ASN1Application extends ASN1Object {
  ASN1Application({
    int applicationTagNumber = 0,
    bool constructed = false,
  })  : applicationTagNumber = applicationTagNumber,
        isConstructedApplication = constructed,
        super(tag: _encodeApplicationTag(applicationTagNumber, constructed));

  ASN1Application.fromBytes(Uint8List bytes)
      : applicationTagNumber = _decodeApplicationTagNumber(bytes),
        isConstructedApplication = (bytes[0] & CONSTRUCTED_BIT) != 0,
        super.fromBytes(bytes) {
    if (!isApplication(tag)) {
      throw ASN1Exception('tag $tag is not an ASN1 Application class');
    }
  }

  /// Lower five bits (or decoded high-tag number) representing the application tag.
  final int applicationTagNumber;

  /// Whether this application tag carries the constructed bit.
  final bool isConstructedApplication;

  static int _encodeApplicationTag(int tagNumber, bool constructed) {
    if (tagNumber < 0 || tagNumber > 0x1e) {
      throw ArgumentError(
          'Application tag number must be between 0 and 30 inclusive');
    }
    var value = APPLICATION_CLASS | (tagNumber & 0x1f);
    if (constructed) {
      value |= CONSTRUCTED_BIT;
    }
    return value;
  }

  static int _decodeApplicationTagNumber(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ASN1Exception('Cannot decode application tag from empty input');
    }
    final base = bytes[0] & 0x1f;
    if (base != 0x1f) {
      return base;
    }
    var value = 0;
    var offset = 1;
    while (offset < bytes.length) {
      final byte = bytes[offset++];
      value = (value << 7) | (byte & 0x7f);
      if ((byte & 0x80) == 0) {
        return value;
      }
    }
    throw ASN1Exception(
        'Truncated high-tag-number while decoding application tag');
  }
}

// Represent an ASN1 PRIVATE type. This is a
// custom ASN1 object that delegates the interpretation to the
// consumer.
class ASN1Private extends ASN1Object {
  ASN1Private({super.tag = PRIVATE_CLASS});

  ASN1Private.fromBytes(super.bytes) : super.fromBytes() {
    // check that this really is an Private type
    if (!isPrivate(tag)) {
      throw ASN1Exception('tag $tag is not an ASN1 Private class');
    }
  }
}

// Represent an ASN1 PRIVATE type. This is a
// custom ASN1 object that delegates the interpretation to the
// consumer.
class ASN1ContextSpecific extends ASN1Object {
  ASN1ContextSpecific({super.tag = PRIVATE_CLASS});

  ASN1ContextSpecific.fromBytes(super.bytes) : super.fromBytes() {
    // check that this really is an Private type
    if (!isContextSpecific(tag)) {
      throw ASN1Exception('tag $tag is not an ASN1 Context specific class');
    }
  }
}


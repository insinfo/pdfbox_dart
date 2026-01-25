import 'dart:convert';
import '../xmp_constants.dart';
import '../xmp_metadata.dart';
import '../schema/xmp_schema.dart';
import '../type/abstract_field.dart';
import '../type/abstract_simple_property.dart';
import '../type/abstract_structured_type.dart';
import '../type/attribute.dart';
import '../type/cardinality.dart';
import '../../utils/xml/xml.dart';

/// Exception for serialization errors.
class XmpSerializationException implements Exception {
  final String message;
  final Object? cause;

  XmpSerializationException(this.message, [this.cause]);

  @override
  String toString() => 'XmpSerializationException: $message ${cause != null ? "(cause: $cause)" : ""}';
}

/// XMP Serializer - serializes XMPMetadata to XML.
/// Ported from org.apache.xmpbox.xml.XmpSerializer
class XmpSerializer {
  
  XmpSerializer();

  /// Serialize XMP metadata to a string.
  /// 
  /// [metadata] The metadata to serialize.
  /// [withXpacket] Whether to include xpacket processing instructions.
  /// Returns the serialized XML as a string.
  String serialize(XMPMetadata metadata, {bool withXpacket = true}) {
    final buffer = StringBuffer();
    
    // Starting xpacket
    if (withXpacket) {
      buffer.writeln('<?xpacket begin="${metadata.xpacketBegin ?? ''}" id="${metadata.xpacketId ?? ''}"?>');
    }
    
    // Build the XML structure
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    
    builder.element('x:xmpmeta', 
      namespaces: {'adobe:ns:meta/': 'x'},
      nest: () {
        builder.element('rdf:RDF',
          namespaces: {XmpConstants.rdfNamespace: 'rdf'},
          nest: () {
            // Serialize each schema
            for (XMPSchema schema in metadata.getAllSchemas()) {
              _serializeSchema(builder, schema);
            }
          }
        );
      }
    );
    
    // Write the XML
    final document = builder.buildDocument();
    buffer.write(document.toXmlString(pretty: true, indent: '  '));
    
    // Ending xpacket
    if (withXpacket) {
      buffer.writeln();
      buffer.write('<?xpacket end="${metadata.endXPacket}"?>');
    }
    
    return buffer.toString();
  }

  /// Serialize XMP metadata to bytes.
  List<int> serializeToBytes(XMPMetadata metadata, {bool withXpacket = true}) {
    return utf8.encode(serialize(metadata, withXpacket: withXpacket));
  }

  void _serializeSchema(XmlBuilder builder, XMPSchema schema) {
    builder.element('rdf:Description',
      attributes: {
        'rdf:about': schema.getAboutValue(),
        'xmlns:${schema.prefix}': schema.namespace,
      },
      nest: () {
        // Serialize schema attributes
        for (Attribute attr in schema.getAllAttributes()) {
          if (attr.name != XmpConstants.aboutName) {
            // Already handled above
            // These are additional attributes if any
          }
        }
        
        // Serialize all properties
        for (AbstractField field in schema.getAllProperties()) {
          _serializeField(builder, field, schema.prefix);
        }
      }
    );
  }

  void _serializeField(XmlBuilder builder, AbstractField field, String defaultPrefix) {
    if (field is AbstractSimpleProperty) {
      _serializeSimpleProperty(builder, field, defaultPrefix);
    } else if (field is ArrayPropertyImpl) {
      _serializeArrayProperty(builder, field, defaultPrefix);
    } else if (field is AbstractStructuredType) {
      _serializeStructuredProperty(builder, field, defaultPrefix);
    }
  }

  void _serializeSimpleProperty(XmlBuilder builder, AbstractSimpleProperty prop, String defaultPrefix) {
    String pref = prop.prefix.isNotEmpty ? prop.prefix : defaultPrefix;
    Map<String, String> attrs = {};
    
    // Add attributes
    for (Attribute attr in prop.getAllAttributes()) {
      if (attr.namespace != null && attr.namespace!.isNotEmpty) {
        // For xml:lang etc.
        attrs[attr.name] = attr.value;
      } else {
        attrs[attr.name] = attr.value;
      }
    }
    
    builder.element('$pref:${prop.propertyName}',
      attributes: attrs,
      nest: () {
        final value = prop.stringValue;
        if (value != null) {
          builder.text(value);
        }
      }
    );
  }

  void _serializeArrayProperty(XmlBuilder builder, ArrayPropertyImpl array, String defaultPrefix) {
    String pref = array.prefix.isNotEmpty ? array.prefix : defaultPrefix;
    
    builder.element('$pref:${array.propertyName}',
      nest: () {
        // Determine array type (Bag, Seq, Alt)
        String arrayType;
        switch (array.cardinality) {
          case Cardinality.bag:
            arrayType = 'Bag';
            break;
          case Cardinality.seq:
            arrayType = 'Seq';
            break;
          case Cardinality.alt:
            arrayType = 'Alt';
            break;
          default:
            arrayType = 'Bag';
        }
        
        builder.element('rdf:$arrayType',
          nest: () {
            for (AbstractField item in array.getAllProperties()) {
              if (item is AbstractSimpleProperty) {
                builder.element('rdf:li',
                  nest: () {
                    final value = item.stringValue;
                    if (value != null) {
                      builder.text(value);
                    }
                  }
                );
              } else {
                // Structured items
                _serializeField(builder, item, defaultPrefix);
              }
            }
          }
        );
      }
    );
  }

  void _serializeStructuredProperty(XmlBuilder builder, AbstractStructuredType structured, String defaultPrefix) {
    String pref = structured.prefix.isNotEmpty ? structured.prefix : defaultPrefix;
    
    builder.element('$pref:${structured.propertyName}',
      nest: () {
        builder.element('rdf:li',
          attributes: {'rdf:parseType': 'Resource'},
          nest: () {
            for (AbstractField field in structured.getAllProperties()) {
              _serializeField(builder, field, structured.prefix);
            }
          }
        );
      }
    );
  }
}


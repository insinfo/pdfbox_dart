import 'abstract_simple_property.dart';
import 'boolean_type.dart';
import 'date_type.dart';
import 'integer_type.dart';
import 'real_type.dart';
import 'text_type.dart';
import 'types.dart';

typedef SimplePropertyFactory = AbstractSimpleProperty Function(
  dynamic metadata,
  String namespace,
  String prefix,
  String propertyName,
  Object? value,
);

class StructuredTypeInfo {
  final String namespace;
  final String prefix;

  const StructuredTypeInfo(this.namespace, this.prefix);
}

/// Type mapping registry for XMP property creation.
class TypeMapping {
  final Map<Types, SimplePropertyFactory> _simpleFactories = {};
  final Map<Type, StructuredTypeInfo> _structuredTypes = {};

  TypeMapping() {
    registerSimpleType(
      Types.text,
      (metadata, namespace, prefix, name, value) =>
          TextType(metadata, namespace, prefix, name, value),
    );
    registerSimpleType(
      Types.date,
      (metadata, namespace, prefix, name, value) =>
          DateType(metadata, namespace, prefix, name, value),
    );
    registerSimpleType(
      Types.boolean_,
      (metadata, namespace, prefix, name, value) =>
          BooleanType(metadata, namespace, prefix, name, value),
    );
    registerSimpleType(
      Types.integer,
      (metadata, namespace, prefix, name, value) =>
          IntegerType(metadata, namespace, prefix, name, value),
    );
    registerSimpleType(
      Types.real,
      (metadata, namespace, prefix, name, value) =>
          RealType(metadata, namespace, prefix, name, value),
    );
  }

  void registerSimpleType(Types type, SimplePropertyFactory factory) {
    _simpleFactories[type] = factory;
  }

  AbstractSimpleProperty createSimpleProperty(
    Types type,
    dynamic metadata,
    String namespace,
    String prefix,
    String propertyName,
    Object? value,
  ) {
    final factory = _simpleFactories[type];
    if (factory == null) {
      return TextType(metadata, namespace, prefix, propertyName, value);
    }
    return factory(metadata, namespace, prefix, propertyName, value);
  }

  AbstractSimpleProperty createSimplePropertyFromValue(
    dynamic metadata,
    String namespace,
    String prefix,
    String propertyName,
    Object? value,
  ) {
    if (value is DateTime) {
      return createSimpleProperty(
        Types.date,
        metadata,
        namespace,
        prefix,
        propertyName,
        value,
      );
    }
    if (value is bool) {
      return createSimpleProperty(
        Types.boolean_,
        metadata,
        namespace,
        prefix,
        propertyName,
        value,
      );
    }
    if (value is int) {
      return createSimpleProperty(
        Types.integer,
        metadata,
        namespace,
        prefix,
        propertyName,
        value,
      );
    }
    if (value is num) {
      return createSimpleProperty(
        Types.real,
        metadata,
        namespace,
        prefix,
        propertyName,
        value,
      );
    }
    return createSimpleProperty(
      Types.text,
      metadata,
      namespace,
      prefix,
      propertyName,
      value?.toString(),
    );
  }

  void registerStructuredType(Type type, StructuredTypeInfo info) {
    _structuredTypes[type] = info;
  }

  StructuredTypeInfo? getStructuredTypeInfo(Type type) {
    return _structuredTypes[type];
  }
}

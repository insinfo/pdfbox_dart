import 'abstract_complex_property.dart';
import 'text_type.dart';
import 'date_type.dart';
import 'cardinality.dart';

/// Abstract class for structured XMP types.
/// Ported from org.apache.xmpbox.type.AbstractStructuredType
abstract class AbstractStructuredType extends AbstractComplexProperty {
  static const String structureArrayName = "li";

  String? _namespace;
  String? _preferedPrefix;
  String? _prefix;

  AbstractStructuredType(dynamic metadata) : this.full(metadata, null, null, null);

  AbstractStructuredType.full(
    dynamic metadata,
    String? namespaceURI,
    String? fieldPrefix,
    String? propertyName,
  ) : super(metadata, propertyName) {
    // In Java, annotation-based initialization is used.
    // In Dart, we rely on parameters or subclass overrides.
    // TODO: Use mirrors or manual registration for structured type metadata.
    if (namespaceURI != null) {
      _namespace = namespaceURI;
      _preferedPrefix = fieldPrefix;
    }
    _prefix = fieldPrefix ?? _preferedPrefix;
  }

  @override
  String get namespace => _namespace ?? '';

  set namespace(String ns) => _namespace = ns;

  @override
  String get prefix => _prefix ?? '';

  set prefix(String pf) => _prefix = pf;

  String? get preferedPrefix => _preferedPrefix;

  void addSimpleProperty(String propertyName, Object value) {
    // TODO: Use TypeMapping to instantiate the correct property type.
    // For now, assume text type.
    TextType prop = TextType(metadata, namespace, prefix, propertyName, value);
    addProperty(prop);
  }

  String? getPropertyValueAsString(String fieldName) {
    var prop = getProperty(fieldName);
    if (prop == null) {
      return null;
    }
    // Assuming it's a simple property
    // TODO: Proper type checking
    return prop.toString();
  }

  DateTime? getDatePropertyAsCalendar(String fieldName) {
    var prop = getFirstEquivalentProperty(fieldName, DateType);
    if (prop is DateType) {
      return prop.value;
    }
    return null;
  }

  TextType createTextType(String propertyName, String value) {
    return TextType(metadata, namespace, prefix, propertyName, value);
  }

  ArrayPropertyImpl createArrayProperty(String propertyName, Cardinality type) {
    return ArrayPropertyImpl(metadata, namespace, prefix, propertyName, type);
  }
}

/// Basic ArrayProperty implementation.
/// TODO: Complete implementation with full XMP array support.
class ArrayPropertyImpl extends ArrayProperty {
  final String _namespace;
  final String _prefix;
  final Cardinality cardinality;

  ArrayPropertyImpl(
    dynamic metadata,
    this._namespace,
    this._prefix,
    String propertyName,
    this.cardinality,
  ) : super(metadata, propertyName);

  @override
  String get namespace => _namespace;

  @override
  String get prefix => _prefix;

  /// Get elements as string list.
  List<String> getElementsAsString() {
    List<String> result = [];
    for (var prop in getAllProperties()) {
      if (prop is TextType) {
        var val = prop.stringValue;
        if (val != null) {
          result.add(val);
        }
      }
    }
    return result;
  }
}


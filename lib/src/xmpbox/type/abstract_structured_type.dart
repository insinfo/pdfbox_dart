import '../xmp_constants.dart';
import '../xmp_metadata_base.dart';
import 'abstract_complex_property.dart';
import 'abstract_field.dart';
import 'abstract_simple_property.dart';
import 'attribute.dart';
import 'cardinality.dart';
import 'date_type.dart';
import 'text_type.dart';

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
    if (namespaceURI != null) {
      _namespace = namespaceURI;
      _preferedPrefix = fieldPrefix;
    } else if (metadata is XMPMetadataBase) {
      final info = metadata.typeMapping.getStructuredTypeInfo(runtimeType);
      if (info != null) {
        _namespace = info.namespace;
        _preferedPrefix = info.prefix;
      }
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
    AbstractSimpleProperty prop;
    final metadataBase = metadata;
    if (metadataBase is XMPMetadataBase) {
      prop = metadataBase.typeMapping.createSimplePropertyFromValue(
        metadataBase,
        namespace,
        prefix,
        propertyName,
        value,
      );
    } else {
      prop = TextType(metadata, namespace, prefix, propertyName, value);
    }
    addProperty(prop);
  }

  String? getPropertyValueAsString(String fieldName) {
    var prop = getProperty(fieldName);
    if (prop == null) {
      return null;
    }
    if (prop is AbstractSimpleProperty) {
      return prop.stringValue;
    }
    return null;
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
class ArrayPropertyImpl extends ArrayProperty {
  final String _namespace;
  final String _prefix;

  ArrayPropertyImpl(
    dynamic metadata,
    this._namespace,
    this._prefix,
    String propertyName,
    Cardinality cardinality,
  ) : super(metadata, propertyName, cardinality);

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

  TextType addTextValue(String value, {String? language}) {
    final item = TextType(metadata, namespace, prefix, XmpConstants.listName, value);
    if (language != null) {
      item.setAttribute(Attribute('http://www.w3.org/XML/1998/namespace', 'xml:lang', language));
    }
    addItem(item);
    return item;
  }

  void removeTextValue(String value, {String? language}) {
    final items = getItems().whereType<TextType>().toList(growable: false);
    for (final item in items) {
      final matchesValue = item.stringValue == value;
      final matchesLang = language == null || item.getAttribute('xml:lang')?.value == language;
      if (matchesValue && matchesLang) {
        removeItem(item);
      }
    }
  }

  List<AbstractField> getItems() => getContainer().getAllProperties();
}


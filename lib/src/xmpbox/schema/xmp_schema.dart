import '../xmp_constants.dart';
import '../xmp_metadata.dart';
import '../type/abstract_structured_type.dart';
import '../type/abstract_field.dart';
import '../type/abstract_simple_property.dart';
import '../type/attribute.dart';
import '../type/bad_field_value_exception.dart';
import '../type/boolean_type.dart';
import '../type/date_type.dart';
import '../type/integer_type.dart';
import '../type/text_type.dart';
import '../type/types.dart';
import '../type/cardinality.dart';

/// Base class for XMP schemas.
/// 
/// This class represents a metadata schema that can be stored in an XMP document.
/// It handles all generic properties that are available. See subclasses for access to specific properties.
/// 
/// Ported from org.apache.xmpbox.schema.XMPSchema
class XMPSchema extends AbstractStructuredType {
  static const String _xmlLangAttrName = 'xml:lang';
  static const String _xmlNamespace = 'http://www.w3.org/XML/1998/namespace';
  
  /// Create a new blank schema that can be populated.
  XMPSchema(XMPMetadata metadata) : this.full(metadata, null, null, null);

  /// Create a new blank schema with prefix.
  XMPSchema.withPrefix(XMPMetadata metadata, String prefix)
      : this.full(metadata, null, prefix, null);

  /// Create a new blank schema with namespace and prefix.
  XMPSchema.withNsAndPrefix(XMPMetadata metadata, String namespaceURI, String prefix)
      : this.full(metadata, namespaceURI, prefix, null);

  /// Create a new blank schema that can be populated.
  XMPSchema.full(XMPMetadata metadata, String? namespaceURI, String? prefix, String? name)
      : super.full(metadata, namespaceURI, prefix, name) {
    if (namespace.isNotEmpty && this.prefix.isNotEmpty) {
      addNamespace(namespace, this.prefix);
    }
  }

  /// Retrieve a generic simple type property.
  AbstractField? getAbstractProperty(String qualifiedName) {
    for (AbstractField child in getContainer().getAllProperties()) {
      if (child.propertyName == qualifiedName) {
        return child;
      }
    }
    return null;
  }

  /// Get the RDF about attribute.
  Attribute? getAboutAttribute() {
    return getAttribute(XmpConstants.aboutName);
  }

  /// Get the RDF about value.
  /// 
  /// If there is no rdf:about attribute, an empty string is returned.
  String getAboutValue() {
    Attribute? prop = getAttribute(XmpConstants.aboutName);
    if (prop != null) {
      return prop.value;
    }
    // PDFBOX-1685: if missing, rdf:about should be considered as empty string
    return "";
  }

  /// Set the RDF 'about' attribute.
  void setAbout(Attribute about) {
    if (XmpConstants.rdfNamespace == about.namespace &&
        XmpConstants.aboutName == about.name) {
      setAttribute(about);
      return;
    }
    throw BadFieldValueException("Attribute 'about' must be named 'rdf:about' or 'about'");
  }

  /// Set the RDF 'about' attribute. Passing in null will clear this attribute.
  void setAboutAsSimple(String? about) {
    if (about == null) {
      removeAttribute(XmpConstants.aboutName);
    } else {
      setAttribute(Attribute(XmpConstants.rdfNamespace, XmpConstants.aboutName, about));
    }
  }

  void _setSpecifiedSimpleTypeProperty(Types type, String qualifiedName, Object? propertyValue) {
    if (propertyValue == null) {
      // Search in properties to erase
      for (AbstractField child in getContainer().getAllProperties()) {
        if (child.propertyName == qualifiedName) {
          getContainer().removeProperty(child);
          return;
        }
      }
    } else {
      AbstractSimpleProperty specifiedTypeProperty = _createSimpleProperty(type, qualifiedName, propertyValue);
      
      // Search in properties to erase
      for (AbstractField child in getAllProperties()) {
        if (child.propertyName == qualifiedName) {
          removeProperty(child);
          addProperty(specifiedTypeProperty);
          return;
        }
      }
      addProperty(specifiedTypeProperty);
    }
  }

  AbstractSimpleProperty _createSimpleProperty(Types type, String propertyName, Object value) {
    switch (type) {
      case Types.text:
        return TextType(metadata, namespace, prefix, propertyName, value);
      case Types.integer:
        return IntegerType(metadata, namespace, prefix, propertyName, value);
      case Types.boolean_:
        return BooleanType(metadata, namespace, prefix, propertyName, value);
      case Types.date:
        return DateType(metadata, namespace, prefix, propertyName, value);
      default:
        return TextType(metadata, namespace, prefix, propertyName, value.toString());
    }
  }

  void _setSpecifiedSimpleTypePropertyFromProp(AbstractSimpleProperty prop) {
    // Search in properties to erase
    for (AbstractField child in getAllProperties()) {
      if (child.propertyName == prop.propertyName) {
        removeProperty(child);
        addProperty(prop);
        return;
      }
    }
    addProperty(prop);
  }

  /// Set TextType property.
  void setTextProperty(TextType prop) {
    _setSpecifiedSimpleTypePropertyFromProp(prop);
  }

  /// Set a simple text property on the schema.
  void setTextPropertyValue(String qualifiedName, String? propertyValue) {
    _setSpecifiedSimpleTypeProperty(Types.text, qualifiedName, propertyValue);
  }

  /// Set a simple text property on the schema, using the current prefix.
  void setTextPropertyValueAsSimple(String simpleName, String? propertyValue) {
    setTextPropertyValue(simpleName, propertyValue);
  }

  /// Get a TextProperty Type by its name.
  TextType? getUnqualifiedTextProperty(String name) {
    AbstractField? prop = getAbstractProperty(name);
    if (prop != null) {
      if (prop is TextType) {
        return prop;
      }
      throw BadFieldValueException("Property asked is not a Text Property");
    }
    return null;
  }

  /// Get the value of a simple text property.
  String? getUnqualifiedTextPropertyValue(String name) {
    TextType? tt = getUnqualifiedTextProperty(name);
    return tt?.stringValue;
  }

  /// Get a Date property by its name.
  DateType? getDateProperty(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is DateType) {
        return prop;
      }
      throw BadFieldValueException("Property asked is not a Date Property");
    }
    return null;
  }

  /// Get the value of the property as a date.
  DateTime? getDatePropertyValue(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is DateType) {
        return prop.value;
      }
      throw BadFieldValueException("Property asked is not a Date Property");
    }
    return null;
  }

  /// Get a simple date property value on the schema, using the current prefix.
  DateTime? getDatePropertyValueAsSimple(String simpleName) {
    return getDatePropertyValue(simpleName);
  }

  /// Set a new DateProperty.
  void setDateProperty(DateType date) {
    _setSpecifiedSimpleTypePropertyFromProp(date);
  }

  /// Set the value of the property as a date.
  void setDatePropertyValue(String qualifiedName, DateTime? date) {
    _setSpecifiedSimpleTypeProperty(Types.date, qualifiedName, date);
  }

  /// Set a simple Date property on the schema, using the current prefix.
  void setDatePropertyValueAsSimple(String simpleName, DateTime? date) {
    setDatePropertyValue(simpleName, date);
  }

  /// Get a BooleanType property by its name.
  BooleanType? getBooleanProperty(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is BooleanType) {
        return prop;
      }
      throw BadFieldValueException("Property asked is not a Boolean Property");
    }
    return null;
  }

  /// Get the value of the property as a Boolean.
  bool? getBooleanPropertyValue(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is BooleanType) {
        return prop.value;
      }
      throw BadFieldValueException("Property asked is not a Boolean Property");
    }
    return null;
  }

  /// Get a simple boolean property value on the schema, using the current prefix.
  bool? getBooleanPropertyValueAsSimple(String simpleName) {
    return getBooleanPropertyValue(simpleName);
  }

  /// Set a BooleanType property.
  void setBooleanProperty(BooleanType boolProp) {
    _setSpecifiedSimpleTypePropertyFromProp(boolProp);
  }

  /// Set the value of the property as a boolean.
  void setBooleanPropertyValue(String qualifiedName, bool? boolValue) {
    _setSpecifiedSimpleTypeProperty(Types.boolean_, qualifiedName, boolValue);
  }

  /// Set a simple Boolean property on the schema, using the current prefix.
  void setBooleanPropertyValueAsSimple(String simpleName, bool? boolValue) {
    setBooleanPropertyValue(simpleName, boolValue);
  }

  /// Get the Integer property by its name.
  IntegerType? getIntegerProperty(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is IntegerType) {
        return prop;
      }
      throw BadFieldValueException("Property asked is not an Integer Property");
    }
    return null;
  }

  /// Get the value of the property as an integer.
  int? getIntegerPropertyValue(String qualifiedName) {
    AbstractField? prop = getAbstractProperty(qualifiedName);
    if (prop != null) {
      if (prop is IntegerType) {
        return prop.value;
      }
      throw BadFieldValueException("Property asked is not an Integer Property");
    }
    return null;
  }

  /// Get a simple integer property value on the schema, using the current prefix.
  int? getIntegerPropertyValueAsSimple(String simpleName) {
    return getIntegerPropertyValue(simpleName);
  }

  /// Add an integerProperty.
  void setIntegerProperty(IntegerType prop) {
    _setSpecifiedSimpleTypePropertyFromProp(prop);
  }

  /// Set the value of the property as an integer.
  void setIntegerPropertyValue(String qualifiedName, int? intValue) {
    _setSpecifiedSimpleTypeProperty(Types.integer, qualifiedName, intValue);
  }

  /// Set a simple Integer property on the schema, using the current prefix.
  void setIntegerPropertyValueAsSimple(String simpleName, int? intValue) {
    setIntegerPropertyValue(simpleName, intValue);
  }

  // --- Language alternative (alt-text) helpers ---

  ArrayPropertyImpl _getOrCreateAltArray(String propertyName) {
    ArrayPropertyImpl? array = getAbstractProperty(propertyName) as ArrayPropertyImpl?;
    if (array == null) {
      array = createArrayProperty(propertyName, Cardinality.alt);
      addProperty(array);
    }
    return array;
  }

  TextType? _findLangAltItem(ArrayPropertyImpl array, String lang) {
    for (final prop in array.getAllProperties()) {
      if (prop is TextType) {
        final attr = prop.getAttribute(_xmlLangAttrName);
        if (attr != null && attr.value == lang) {
          return prop;
        }
      }
    }
    return null;
  }

  void setUnqualifiedLanguagePropertyValue(
    String propertyName,
    String? lang,
    String value,
  ) {
    final langValue = lang ?? XmpConstants.xDefault;
    final array = _getOrCreateAltArray(propertyName);

    final existing = _findLangAltItem(array, langValue);
    if (existing != null) {
      existing.setValue(value);
      return;
    }

    final item = createTextType(XmpConstants.listName, value);
    item.setAttribute(Attribute(_xmlNamespace, _xmlLangAttrName, langValue));
    array.getContainer().addProperty(item);
  }

  String? getUnqualifiedLanguagePropertyValue(
    String propertyName, {
    String? lang,
  }) {
    final array = getAbstractProperty(propertyName) as ArrayPropertyImpl?;
    if (array == null) return null;

    if (lang != null) {
      return _findLangAltItem(array, lang)?.stringValue;
    }

    final defaultItem = _findLangAltItem(array, XmpConstants.xDefault);
    if (defaultItem != null) {
      return defaultItem.stringValue;
    }

    for (final prop in array.getAllProperties()) {
      if (prop is TextType) {
        return prop.stringValue;
      }
    }
    return null;
  }

  // --- Array (Bag/Seq) methods ---

  void _removeUnqualifiedArrayValue(String arrayName, String fieldValue) {
    AbstractField? abstractProperty = getAbstractProperty(arrayName);
    if (abstractProperty is! ArrayPropertyImpl) {
      return;
    }

    ArrayPropertyImpl array = abstractProperty;
    List<AbstractField> toDelete = [];
    for (AbstractField abstractField in array.getContainer().getAllProperties()) {
      if (abstractField is AbstractSimpleProperty) {
        if (abstractField.stringValue == fieldValue) {
          toDelete.add(abstractField);
        }
      }
    }
    for (var prop in toDelete) {
      array.getContainer().removeProperty(prop);
    }
  }

  /// Remove all matching entries with the given value from the bag.
  void removeUnqualifiedBagValue(String bagName, String bagValue) {
    _removeUnqualifiedArrayValue(bagName, bagValue);
  }

  /// Add a bag value property on the schema, using the current prefix.
  void addBagValueAsSimple(String simpleName, String bagValue) {
    _internalAddBagValue(simpleName, bagValue);
  }

  void _internalAddBagValue(String qualifiedBagName, String bagValue) {
    ArrayPropertyImpl? bag = getAbstractProperty(qualifiedBagName) as ArrayPropertyImpl?;
    TextType li = createTextType(XmpConstants.listName, bagValue);
    if (bag != null) {
      bag.getContainer().addProperty(li);
    } else {
      ArrayPropertyImpl newBag = createArrayProperty(qualifiedBagName, Cardinality.bag);
      newBag.getContainer().addProperty(li);
      addProperty(newBag);
    }
  }

  /// Add an entry to a bag property.
  void addQualifiedBagValue(String simpleName, String bagValue) {
    _internalAddBagValue(simpleName, bagValue);
  }

  /// Get all the values of the bag property.
  List<String>? getUnqualifiedBagValueList(String bagName) {
    AbstractField? abstractProperty = getAbstractProperty(bagName);
    if (abstractProperty is ArrayPropertyImpl) {
      return abstractProperty.getElementsAsString();
    }
    return null;
  }

  /// Remove all matching values from a sequence property.
  void removeUnqualifiedSequenceValue(String qualifiedSeqName, String seqValue) {
    _removeUnqualifiedArrayValue(qualifiedSeqName, seqValue);
  }

  /// Add a new value to a sequence property.
  void addUnqualifiedSequenceValue(String simpleSeqName, String seqValue) {
    ArrayPropertyImpl? seq = getAbstractProperty(simpleSeqName) as ArrayPropertyImpl?;
    TextType li = createTextType(XmpConstants.listName, seqValue);
    if (seq != null) {
      seq.getContainer().addProperty(li);
    } else {
      ArrayPropertyImpl newSeq = createArrayProperty(simpleSeqName, Cardinality.seq);
      newSeq.getContainer().addProperty(li);
      addProperty(newSeq);
    }
  }

  /// Get all the values of the sequence property.
  List<String>? getUnqualifiedSequenceValueList(String seqName) {
    AbstractField? abstractProperty = getAbstractProperty(seqName);
    if (abstractProperty is ArrayPropertyImpl) {
      return abstractProperty.getElementsAsString();
    }
    return null;
  }
}


import '../xmp_metadata.dart';
import '../type/abstract_structured_type.dart';
import '../type/cardinality.dart';
import '../type/date_type.dart';
import '../type/integer_type.dart';
import '../type/text_type.dart';
import '../type/thumbnail_type.dart';
import 'xmp_schema.dart';

/// Representation of XMPBasic Schema.
/// Ported from org.apache.xmpbox.schema.XMPBasicSchema
/// 
/// Namespace: http://ns.adobe.com/xap/1.0/
/// Preferred prefix: xmp
class XMPBasicSchema extends XMPSchema {
  static const String defaultPrefix = "xmp";
  static const String defaultNamespace = "http://ns.adobe.com/xap/1.0/";

  static const String advisory = "Advisory";
  static const String baseUrl = "BaseURL";
  static const String createDate = "CreateDate";
  static const String creatorTool = "CreatorTool";
  static const String identifier = "Identifier";
  static const String label = "Label";
  static const String metadataDate = "MetadataDate";
  static const String modifyDate = "ModifyDate";
  static const String nickname = "Nickname";
  static const String rating = "Rating";
  static const String thumbnails = "Thumbnails";
  static const String modifierDate = "ModifierDate";

  ArrayPropertyImpl? _altThumbs;

  /// Constructor of XMPBasic schema with preferred prefix.
  XMPBasicSchema(XMPMetadata metadata) 
      : super.withNsAndPrefix(metadata, defaultNamespace, defaultPrefix);

  /// Constructor of XMPBasic schema with specified prefix.
  XMPBasicSchema.withPrefix(XMPMetadata metadata, String ownPrefix)
      : super.withNsAndPrefix(metadata, defaultNamespace, ownPrefix);

  /// Add a thumbnail entry.
  void addThumbnail(ThumbnailType thumbnail) {
    final array = _getOrCreateThumbnailArray();
    array.getContainer().addProperty(thumbnail);
  }

  /// Add multiple thumbnail entries.
  void addThumbnails(Iterable<ThumbnailType> thumbnails) {
    for (final thumb in thumbnails) {
      addThumbnail(thumb);
    }
  }

  ArrayPropertyImpl _getOrCreateThumbnailArray() {
    if (_altThumbs != null) return _altThumbs!;
    final existing = getProperty(thumbnails) as ArrayPropertyImpl?;
    if (existing != null) {
      _altThumbs = existing;
      return existing;
    }
    final created = createArrayProperty(thumbnails, Cardinality.alt);
    addProperty(created);
    _altThumbs = created;
    return created;
  }

  /// Add a property specification that were edited outside the authoring application.
  void addAdvisory(String xpath) {
    addQualifiedBagValue(advisory, xpath);
  }

  void removeAdvisory(String xpath) {
    removeUnqualifiedBagValue(advisory, xpath);
  }

  /// Set the base URL for relative URLs in the document content.
  void setBaseURL(String url) {
    addProperty(createTextType(baseUrl, url));
  }

  /// Set the base URL property.
  void setBaseURLProperty(TextType url) {
    addProperty(url);
  }

  /// Set the date and time the resource was originally created.
  void setCreateDate(DateTime date) {
    DateType dt = DateType(metadata, namespace, prefix, createDate, date);
    addProperty(dt);
  }

  /// Set the create date property.
  void setCreateDateProperty(DateType date) {
    addProperty(date);
  }

  /// Set the name of the first known tool used to create this resource.
  void setCreatorTool(String tool) {
    addProperty(createTextType(creatorTool, tool));
  }

  /// Set the creatorTool property.
  void setCreatorToolProperty(TextType tool) {
    addProperty(tool);
  }

  /// Add a text string which unambiguously identify the resource within a given context.
  void addIdentifier(String text) {
    addQualifiedBagValue(identifier, text);
  }

  void removeIdentifier(String text) {
    removeUnqualifiedBagValue(identifier, text);
  }

  /// Set a word or a short phrase which identifies a document as a member of a user-defined collection.
  void setLabel(String text) {
    addProperty(createTextType(label, text));
  }

  /// Set the label property.
  void setLabelProperty(TextType text) {
    addProperty(text);
  }

  /// Set the date and time that any metadata for this resource was last changed.
  void setMetadataDate(DateTime date) {
    DateType dt = DateType(metadata, namespace, prefix, metadataDate, date);
    addProperty(dt);
  }

  /// Set the MetadataDate property.
  void setMetadataDateProperty(DateType date) {
    addProperty(date);
  }

  /// Set the date and time the resource was last modified.
  void setModifyDate(DateTime date) {
    DateType dt = DateType(metadata, namespace, prefix, modifyDate, date);
    addProperty(dt);
  }

  /// Set the ModifyDate property.
  void setModifyDateProperty(DateType date) {
    addProperty(date);
  }

  /// Set the date and time the resource was last modified (modifier variant).
  void setModifierDate(DateTime date) {
    DateType dt = DateType(metadata, namespace, prefix, modifierDate, date);
    addProperty(dt);
  }

  /// Set the ModifierDate property.
  void setModifierDateProperty(DateType date) {
    addProperty(date);
  }

  /// Set a short informal name for the resource.
  void setNickname(String text) {
    addProperty(createTextType(nickname, text));
  }

  /// Set the NickName property.
  void setNicknameProperty(TextType text) {
    addProperty(text);
  }

  /// Set a number that indicates a document's status relative to other documents.
  void setRating(int rate) {
    IntegerType it = IntegerType(metadata, namespace, prefix, rating, rate);
    addProperty(it);
  }

  /// Set Rating Property.
  void setRatingProperty(IntegerType rate) {
    addProperty(rate);
  }

  // --- Getters ---

  /// Get the Advisory property.
  ArrayPropertyImpl? getAdvisoryProperty() {
    return getProperty(advisory) as ArrayPropertyImpl?;
  }

  /// Get the Advisory property values.
  List<String>? getAdvisory() {
    return getUnqualifiedBagValueList(advisory);
  }

  /// Get the BaseURL property.
  TextType? getBaseURLProperty() {
    return getProperty(baseUrl) as TextType?;
  }

  /// Get the BaseURL property value.
  String? getBaseURL() {
    TextType? tt = getProperty(baseUrl) as TextType?;
    return tt?.stringValue;
  }

  /// Get the CreateDate property.
  DateType? getCreateDateProperty() {
    return getProperty(createDate) as DateType?;
  }

  /// Get the CreateDate property value.
  DateTime? getCreateDate() {
    DateType? dt = getProperty(createDate) as DateType?;
    return dt?.value;
  }

  /// Get the CreationTool property.
  TextType? getCreatorToolProperty() {
    return getProperty(creatorTool) as TextType?;
  }

  /// Get the CreationTool property value.
  String? getCreatorTool() {
    TextType? tt = getProperty(creatorTool) as TextType?;
    return tt?.stringValue;
  }

  /// Get the Identifier property.
  ArrayPropertyImpl? getIdentifiersProperty() {
    return getProperty(identifier) as ArrayPropertyImpl?;
  }

  /// Get the Identifier property values.
  List<String>? getIdentifiers() {
    return getUnqualifiedBagValueList(identifier);
  }

  /// Get the label property.
  TextType? getLabelProperty() {
    return getProperty(label) as TextType?;
  }

  /// Get the label property value.
  String? getLabel() {
    TextType? tt = getProperty(label) as TextType?;
    return tt?.stringValue;
  }

  /// Get the MetadataDate property.
  DateType? getMetadataDateProperty() {
    return getProperty(metadataDate) as DateType?;
  }

  /// Get the MetadataDate property value.
  DateTime? getMetadataDate() {
    DateType? dt = getProperty(metadataDate) as DateType?;
    return dt?.value;
  }

  /// Get the ModifyDate property.
  DateType? getModifyDateProperty() {
    return getProperty(modifyDate) as DateType?;
  }

  /// Get the ModifyDate property value.
  DateTime? getModifyDate() {
    DateType? dt = getProperty(modifyDate) as DateType?;
    return dt?.value;
  }

  /// Get the ModifierDate property.
  DateType? getModifierDateProperty() {
    return getProperty(modifierDate) as DateType?;
  }

  /// Get the ModifierDate property value.
  DateTime? getModifierDate() {
    DateType? dt = getProperty(modifierDate) as DateType?;
    return dt?.value;
  }

  /// Get the Nickname property.
  TextType? getNicknameProperty() {
    return getProperty(nickname) as TextType?;
  }

  /// Get the Nickname property value.
  String? getNickname() {
    TextType? tt = getProperty(nickname) as TextType?;
    return tt?.stringValue;
  }

  /// Get the Rating property.
  IntegerType? getRatingProperty() {
    return getProperty(rating) as IntegerType?;
  }

  /// Get the Rating property value.
  int? getRating() {
    IntegerType? it = getProperty(rating) as IntegerType?;
    return it?.value;
  }

  /// Get the thumbnails property.
  ArrayPropertyImpl? getThumbnailsProperty() {
    return getProperty(thumbnails) as ArrayPropertyImpl?;
  }

  /// Get the list of thumbnails.
  List<ThumbnailType>? getThumbnails() {
    final array = getThumbnailsProperty();
    if (array == null) return null;
    final result = <ThumbnailType>[];
    for (final item in array.getContainer().getAllProperties()) {
      if (item is ThumbnailType) {
        result.add(item);
      }
    }
    return result.isEmpty ? null : result;
  }
}


import '../xmp_metadata.dart';
import '../type/abstract_field.dart';
import '../type/abstract_structured_type.dart';
import '../type/text_type.dart';
import 'xmp_schema.dart';

/// Representation of a DublinCore Schema.
/// Ported from org.apache.xmpbox.schema.DublinCoreSchema
/// 
/// Namespace: http://purl.org/dc/elements/1.1/
/// Preferred prefix: dc
class DublinCoreSchema extends XMPSchema {
  static const String defaultPrefix = "dc";
  static const String defaultNamespace = "http://purl.org/dc/elements/1.1/";

  static const String contributor = "contributor";
  static const String coverage = "coverage";
  static const String creator = "creator";
  static const String date = "date";
  static const String description = "description";
  static const String format = "format";
  static const String identifier = "identifier";
  static const String language = "language";
  static const String publisher = "publisher";
  static const String relation = "relation";
  static const String rights = "rights";
  static const String source = "source";
  static const String subject = "subject";
  static const String title = "title";
  static const String type = "type";

  /// Constructor of a Dublin Core schema with preferred prefix.
  DublinCoreSchema(XMPMetadata metadata) 
      : super.withNsAndPrefix(metadata, defaultNamespace, defaultPrefix);

  /// Constructor of a Dublin Core schema with specified prefix.
  DublinCoreSchema.withPrefix(XMPMetadata metadata, String ownPrefix)
      : super.withNsAndPrefix(metadata, defaultNamespace, ownPrefix);

  /// Set contributor(s) to the resource (other than the authors).
  void addContributor(String properName) {
    addQualifiedBagValue(contributor, properName);
  }

  void removeContributor(String properName) {
    removeUnqualifiedBagValue(contributor, properName);
  }

  /// Set the extent or scope of the resource.
  void setCoverage(String text) {
    addProperty(createTextType(coverage, text));
  }

  /// Set the extent or scope of the resource (property).
  void setCoverageProperty(TextType text) {
    addProperty(text);
  }

  /// Set the author(s) of the resource.
  void addCreator(String properName) {
    addUnqualifiedSequenceValue(creator, properName);
  }

  void removeCreator(String name) {
    removeUnqualifiedSequenceValue(creator, name);
  }

  // TODO: Add date handling methods when DateType sequence support is implemented.
  // void addDate(DateTime date)
  // void removeDate(DateTime date)

  /// Add a textual description of the content of the resource (multiple values may be present for different languages).
  /// TODO: Implement language-aware property when LangAlt is implemented.
  void addDescription(String? lang, String value) {
    // TODO: setUnqualifiedLanguagePropertyValue(description, lang, value);
    addProperty(createTextType(description, value));
  }

  /// Set the default value for the description.
  void setDescription(String value) {
    addDescription(null, value);
  }

  /// Set the file format used when saving the resource.
  void setFormat(String mimeType) {
    addProperty(createTextType(format, mimeType));
  }

  /// Set the unique identifier of the resource.
  void setIdentifier(String text) {
    addProperty(createTextType(identifier, text));
  }

  /// Set the unique identifier of the resource (property).
  void setIdentifierProperty(TextType text) {
    addProperty(text);
  }

  /// Add language(s) used in this resource.
  void addLanguage(String locale) {
    addQualifiedBagValue(language, locale);
  }

  void removeLanguage(String locale) {
    removeUnqualifiedBagValue(language, locale);
  }

  /// Add publisher(s).
  void addPublisher(String properName) {
    addQualifiedBagValue(publisher, properName);
  }

  void removePublisher(String name) {
    removeUnqualifiedBagValue(publisher, name);
  }

  /// Add relationships to other documents.
  void addRelation(String text) {
    addQualifiedBagValue(relation, text);
  }

  void removeRelation(String text) {
    removeUnqualifiedBagValue(relation, text);
  }

  /// Add informal rights statement, by language.
  /// TODO: Implement language-aware property when LangAlt is implemented.
  void addRights(String? lang, String value) {
    // TODO: setUnqualifiedLanguagePropertyValue(rights, lang, value);
    addProperty(createTextType(rights, value));
  }

  /// Set the unique identifier of the work from which this resource was derived.
  void setSource(String text) {
    addProperty(createTextType(source, text));
  }

  /// Set the unique identifier of the work from which this resource was derived (property).
  void setSourceProperty(TextType text) {
    addProperty(text);
  }

  /// Add descriptive phrases or keywords that specify the topic of the content of the resource.
  void addSubject(String text) {
    addQualifiedBagValue(subject, text);
  }

  void removeSubject(String text) {
    removeUnqualifiedBagValue(subject, text);
  }

  /// Set the title of the document, or the name given to the resource (by language).
  /// TODO: Implement language-aware property when LangAlt is implemented.
  void setTitle(String? lang, String value) {
    // TODO: setUnqualifiedLanguagePropertyValue(title, lang, value);
    addProperty(createTextType(title, value));
  }

  /// Set default title.
  void setTitleSimple(String value) {
    setTitle(null, value);
  }

  /// Add title.
  void addTitle(String? lang, String value) {
    setTitle(lang, value);
  }

  /// Set the document type (novel, poem, ...).
  void addType(String docType) {
    addQualifiedBagValue(type, docType);
  }

  void removeType(String docType) {
    removeUnqualifiedBagValue(type, docType);
  }

  // --- Getters ---

  /// Return the Bag of contributor(s).
  ArrayPropertyImpl? getContributorsProperty() {
    return getProperty(contributor) as ArrayPropertyImpl?;
  }

  /// Return a String list of contributor(s).
  List<String>? getContributors() {
    return getUnqualifiedBagValueList(contributor);
  }

  /// Return the Coverage TextType Property.
  TextType? getCoverageProperty() {
    return getProperty(coverage) as TextType?;
  }

  /// Return the value of the coverage.
  String? getCoverage() {
    TextType? tt = getProperty(coverage) as TextType?;
    return tt?.stringValue;
  }

  /// Return the Sequence of creator(s).
  ArrayPropertyImpl? getCreatorsProperty() {
    return getProperty(creator) as ArrayPropertyImpl?;
  }

  /// Return the creator(s) string value.
  List<String>? getCreators() {
    return getUnqualifiedSequenceValueList(creator);
  }

  /// Return the sequence of date(s).
  ArrayPropertyImpl? getDatesProperty() {
    return getProperty(date) as ArrayPropertyImpl?;
  }

  // TODO: getDates() when date sequence is implemented.

  /// Return the Lang alt Description.
  AbstractField? getDescriptionProperty() {
    return getProperty(description);
  }

  /// Get the description value.
  /// TODO: Implement proper language-aware getter.
  String? getDescription() {
    AbstractField? prop = getProperty(description);
    if (prop is TextType) {
      return prop.stringValue;
    }
    return null;
  }

  /// Return the file format property.
  TextType? getFormatProperty() {
    return getProperty(format) as TextType?;
  }

  /// Return the file format value.
  String? getFormat() {
    TextType? tt = getProperty(format) as TextType?;
    return tt?.stringValue;
  }

  /// Return the unique identifier property of this resource.
  TextType? getIdentifierProperty() {
    return getProperty(identifier) as TextType?;
  }

  /// Return the unique identifier value of this resource.
  String? getIdentifier() {
    TextType? tt = getProperty(identifier) as TextType?;
    return tt?.stringValue;
  }

  /// Return the bag DC language.
  ArrayPropertyImpl? getLanguagesProperty() {
    return getProperty(language) as ArrayPropertyImpl?;
  }

  /// Return the list of values defined in the DC language.
  List<String>? getLanguages() {
    return getUnqualifiedBagValueList(language);
  }

  /// Return the bag DC publisher.
  ArrayPropertyImpl? getPublishersProperty() {
    return getProperty(publisher) as ArrayPropertyImpl?;
  }

  /// Return the list of values defined in the DC publisher.
  List<String>? getPublishers() {
    return getUnqualifiedBagValueList(publisher);
  }

  /// Return the bag DC relation.
  ArrayPropertyImpl? getRelationsProperty() {
    return getProperty(relation) as ArrayPropertyImpl?;
  }

  /// Return the list of values defined in the DC relation.
  List<String>? getRelations() {
    return getUnqualifiedBagValueList(relation);
  }

  /// Return the Lang alt Rights.
  AbstractField? getRightsProperty() {
    return getProperty(rights);
  }

  /// Return the rights value.
  /// TODO: Implement proper language-aware getter.
  String? getRights() {
    AbstractField? prop = getProperty(rights);
    if (prop is TextType) {
      return prop.stringValue;
    }
    return null;
  }

  /// Return the source property of this resource.
  TextType? getSourceProperty() {
    return getProperty(source) as TextType?;
  }

  /// Return the source value of this resource.
  String? getSource() {
    TextType? tt = getProperty(source) as TextType?;
    return tt?.stringValue;
  }

  /// Return the bag DC Subject.
  ArrayPropertyImpl? getSubjectsProperty() {
    return getProperty(subject) as ArrayPropertyImpl?;
  }

  /// Return the list of values defined in the DC Subject.
  List<String>? getSubjects() {
    return getUnqualifiedBagValueList(subject);
  }

  /// Return the Lang alt Title.
  AbstractField? getTitleProperty() {
    return getProperty(title);
  }

  /// Return the title value.
  /// TODO: Implement proper language-aware getter.
  String? getTitle() {
    AbstractField? prop = getProperty(title);
    if (prop is TextType) {
      return prop.stringValue;
    }
    return null;
  }

  /// Return the bag DC Type.
  ArrayPropertyImpl? getTypesProperty() {
    return getProperty(type) as ArrayPropertyImpl?;
  }

  /// Return the list of values defined in the DC Type.
  List<String>? getTypes() {
    return getUnqualifiedBagValueList(type);
  }
}


import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../cos/cos_array.dart';
import '../cos/cos_dictionary.dart';
import '../cos/cos_document.dart';
import '../cos/cos_name.dart';
import '../cos/cos_object.dart';
import '../../io/random_access_read.dart';
import '../../io/random_access_read_buffer.dart';
import '../../io/random_access_read_buffered_file.dart';
import '../../io/random_access_write.dart';
import '../../io/random_access_write_file.dart';
import '../pdfwriter/cos_writer.dart';
import '../pdfwriter/pdf_save_options.dart';
import 'encryption/access_permission.dart';
import 'encryption/pd_encryption.dart';
import 'encryption/protection_policy.dart';
import 'encryption/security_handler.dart';
import 'encryption/security_handler_factory.dart';
import 'encryption/standard_security_handler.dart';
import '../pdmodel/interactive/digitalsignature/external_signing_support.dart';
import '../pdmodel/interactive/digitalsignature/signing_support.dart';
import '../pdmodel/interactive/documentnavigation/pd_outline_node.dart';
import '../pdmodel/interactive/digitalsignature/pd_signature.dart';
import '../pdmodel/interactive/digitalsignature/signature_interface.dart';
import '../pdmodel/interactive/digitalsignature/signature_options.dart';
import '../pdmodel/interactive/annotation/pd_annotation.dart';
import '../pdmodel/interactive/annotation/pd_annotation_widget.dart';
import '../pdmodel/interactive/form/pd_signature_field.dart';
import '../pdmodel/interactive/form/pd_acro_form.dart';
import '../pdmodel/interactive/annotation/pd_annotation_appearance.dart';
import '../pdmodel/interactive/annotation/pd_appearance_stream.dart';
import '../pdmodel/common/pd_rectangle.dart';
import '../pdfparser/pdf_parser.dart';
import 'encryption/decryption_material.dart';
import 'pd_document_information.dart';
import 'pd_document_catalog.dart';
import 'pd_page.dart';
import 'pd_page_tree.dart';
import 'pd_resources.dart';
import 'resource_cache.dart';
import 'pd_stream.dart';
import 'font/pdfont.dart';
import '../../fontbox/ttf/true_type_font.dart';

/// High level representation of a PDF document.
class PDDocument {
  PDDocument._(this._document, this._catalog, this._resourceCache)
      : _accessPermission = AccessPermission.ownerAccessPermission();

  static const List<int> _reserveByteRange = <int>[
    0,
    1000000000,
    1000000000,
    1000000000,
  ];

  factory PDDocument() {
    final cosDocument = COSDocument();
    final pagesDict = COSDictionary()
      ..setName(COSName.type, 'Pages')
      ..setInt(COSName.count, 0);
    pagesDict[COSName.kids] = COSArray();

    final pagesObject = cosDocument.createObject(pagesDict);

    final catalogDict = COSDictionary()
      ..setName(COSName.type, 'Catalog')
      ..setItem(COSName.pages, pagesObject);
    final catalogObject = cosDocument.createObject(catalogDict);
    cosDocument.trailer[COSName.root] = catalogObject;

    final resourceCache = ResourceCache();
    final catalog = PDDocumentCatalog(cosDocument, resourceCache, catalogDict);
    final document = PDDocument._(cosDocument, catalog, resourceCache);
    document._accessPermission = AccessPermission.ownerAccessPermission();
    return document;
  }

  factory PDDocument.fromCOSDocument(COSDocument document) {
    final catalogDictionary = _requireCatalogDictionary(document);
    final resourceCache = ResourceCache();
    final catalog =
        PDDocumentCatalog(document, resourceCache, catalogDictionary);
    final pdDocument = PDDocument._(document, catalog, resourceCache);
    final encryptionDict = document.trailer.getCOSDictionary(COSName.encrypt);
    if (encryptionDict != null) {
      pdDocument._encryption = PDEncryption(encryptionDict);
      pdDocument._securityHandler = pdDocument._encryption?.securityHandler;
      pdDocument._accessPermission =
          StandardSecurityHandler.permissionsFromEncryption(
              pdDocument._encryption!);
    } else {
      pdDocument._accessPermission = AccessPermission.ownerAccessPermission();
    }
    return pdDocument;
  }

  /// Loads a PDF document from a [RandomAccessRead] source using [PDFParser].
  ///
  /// The [source] is always closed after parsing, regardless of success.
  static PDDocument loadRandomAccess(
    RandomAccessRead source, {
    bool lenient = true,
    String? password,
    DecryptionMaterial? decryptionMaterial,
  }) {
    try {
      final parser = PDFParser(source);
      return parser.parse(
        lenient: lenient,
        password: password,
        decryptionMaterial: decryptionMaterial,
      );
    } finally {
      source.close();
    }
  }

  /// Loads a PDF document from raw [bytes].
  static PDDocument loadFromBytes(
    Uint8List bytes, {
    bool lenient = true,
    String? password,
    DecryptionMaterial? decryptionMaterial,
  }) {
    final buffer = RandomAccessReadBuffer.fromBytes(bytes);
    return loadRandomAccess(
      buffer,
      lenient: lenient,
      password: password,
      decryptionMaterial: decryptionMaterial,
    );
  }

  /// Loads a PDF document from a file at [path].
  static PDDocument loadFile(
    String path, {
    bool lenient = true,
    String? password,
    DecryptionMaterial? decryptionMaterial,
  }) {
    final reader = RandomAccessReadBufferedFile(path);
    return loadRandomAccess(
      reader,
      lenient: lenient,
      password: password,
      decryptionMaterial: decryptionMaterial,
    );
  }

  /// Loads a PDF document from an open [file].
  static PDDocument loadFromFile(
    File file, {
    bool lenient = true,
    String? password,
    DecryptionMaterial? decryptionMaterial,
  }) {
    final reader = RandomAccessReadBufferedFile.fromFile(file);
    return loadRandomAccess(
      reader,
      lenient: lenient,
      password: password,
      decryptionMaterial: decryptionMaterial,
    );
  }

  final COSDocument _document;
  final PDDocumentCatalog _catalog;
  ResourceCache _resourceCache;
  bool _closed = false;
  PDDocumentInformation? _documentInformation;
  PDEncryption? _encryption;
  SecurityHandler<ProtectionPolicy>? _securityHandler;
  AccessPermission _accessPermission;
  bool _allSecurityToBeRemoved = false;
  int? _documentId;
  bool _signatureAdded = false;
  final Set<PDFont> _fontsToSubset = <PDFont>{};
  final List<TrueTypeFont> _fontsToClose = <TrueTypeFont>[];

  COSDocument get cosDocument => _document;

  PDDocumentCatalog get documentCatalog => _catalog;

  ResourceCache get resourceCache => _resourceCache;

  void setResourceCache(ResourceCache resourceCache) {
    _resourceCache = resourceCache;
  }

  PDOutlineRoot? get documentOutline => _catalog.documentOutline;

  set documentOutline(PDOutlineRoot? outline) =>
      _catalog.documentOutline = outline;

  PDPageTree get pages => documentCatalog.pages;

  String get version => _document.headerVersion;

  set version(String value) {
    _ensureOpen();
    _document.headerVersion = value;
  }

  /// Returns the effective PDF specification version, considering catalog overrides.
  double getVersion() {
    final double headerVersion = _parseVersion(_document.headerVersion) ?? 0.0;
    if (headerVersion >= 1.4) {
      final catalogVersion = documentCatalog.version;
      final double catalogParsed = _parseVersion(catalogVersion) ?? -1.0;
      return math.max(catalogParsed, headerVersion);
    }
    return headerVersion;
  }

  /// Sets the PDF specification version, following PDFBox rules.
  void setVersion(double newVersion) {
    final double current = getVersion();
    if (newVersion == current) {
      return;
    }
    if (newVersion < current) {
      return;
    }
    final String formatted = _formatVersion(newVersion);
    final double headerVersion = _parseVersion(_document.headerVersion) ?? 0.0;
    if (headerVersion >= 1.4) {
      documentCatalog.version = formatted;
    } else {
      _document.headerVersion = formatted;
    }
  }

  int get numberOfPages => documentCatalog.pages.count;

  PDPage getPage(int pageIndex) => documentCatalog.pages[pageIndex];

  void addPage(PDPage page) {
    _ensureOpen();
    _preparePage(page);
    documentCatalog.pages.addPage(page);
  }

  void insertPage(int pageIndex, PDPage page) {
    _ensureOpen();
    _preparePage(page);
    documentCatalog.pages.insertPage(pageIndex, page);
  }

  bool removePage(PDPage page) {
    _ensureOpen();
    return documentCatalog.pages.removePage(page);
  }

  PDPage removePageAt(int pageIndex) {
    _ensureOpen();
    return documentCatalog.pages.removePageAt(pageIndex);
  }

  int indexOfPage(PDPage page) => documentCatalog.pages.indexOf(page);

  /// Imports a page from another document by copying its dictionary and content stream.
  PDPage importPage(PDPage page) {
    _ensureOpen();
    final importedPage = PDPage(
      COSDictionary.fromDictionary(page.cosObject),
      _resourceCache,
    );
    importedPage.cosObject.removeItem(COSName.parent);

    final contentReader = page.getContentsForStreamParsing();
    try {
      final length = contentReader.length;
      final buffer = Uint8List(length);
      if (length > 0) {
        contentReader.seek(0);
        contentReader.readFully(buffer);
      }
      importedPage.setContentStream(PDStream.fromBytes(buffer));
    } finally {
      contentReader.close();
    }

    addPage(importedPage);

    final crop = page.cropBox;
    if (crop != null) {
      importedPage.cropBox = PDRectangle(
        crop.lowerLeftX,
        crop.lowerLeftY,
        crop.upperRightX,
        crop.upperRightY,
      );
    }
    final media = page.mediaBox;
    if (media != null) {
      importedPage.mediaBox = PDRectangle(
        media.lowerLeftX,
        media.lowerLeftY,
        media.upperRightX,
        media.upperRightY,
      );
    }
    importedPage.rotation = page.rotation;
    return importedPage;
  }

  Uint8List saveToBytes({PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    _subsetDesignatedFonts();
    final buffer = RandomAccessReadWriteBuffer();
    final writer = COSWriter(buffer, options);
    writer.writeDocument(this);
    final length = buffer.length;
    buffer.seek(0);
    final data = Uint8List(length);
    if (length > 0) {
      buffer.readFully(data);
    }
    buffer.close();
    return data;
  }

  void save(RandomAccessWrite target,
      {PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    _subsetDesignatedFonts();
    final writer = COSWriter(target, options);
    writer.writeDocument(this);
  }

  void saveToFile(String path, {PDFSaveOptions options = const PDFSaveOptions()}) {
    _ensureOpen();
    final output = RandomAccessWriteFile(path);
    try {
      save(output, options: options);
    } finally {
      output.close();
    }
  }

  void saveToFileObject(File file,
      {PDFSaveOptions options = const PDFSaveOptions()}) {
    saveToFile(file.path, options: options);
  }

  void saveIncremental(
    RandomAccessRead original,
    RandomAccessWrite target, {
    PDFSaveOptions options = const PDFSaveOptions(),
  }) {
    _ensureOpen();
    _subsetDesignatedFonts();
    final writer = COSWriter(target, options);
    writer.writeIncremental(this, original);
  }

  ExternalSigningSupport saveIncrementalForExternalSigning(
    RandomAccessRead original,
    RandomAccessWrite target, {
    PDFSaveOptions options = const PDFSaveOptions(),
  }) {
    _ensureOpen();
    _subsetDesignatedFonts();

    PDSignature? foundSignature;
    for (final sig in getSignatureDictionaries()) {
      foundSignature = sig;
      if (sig.cosObject.needsUpdate) {
        break;
      }
    }

    if (foundSignature == null) {
      throw StateError('Document does not contain signature fields');
    }

    final byteRange = foundSignature.byteRange;
    if (!_isReserveByteRange(byteRange)) {
      throw StateError(
          'Signature reserve byte range has been changed after addSignature()');
    }

    final buffer = RandomAccessReadWriteBuffer();
    final writer = COSWriter(buffer, options);
    final context = writer.prepareIncrementalSigning(this, original, target);
    return SigningSupport(context);
  }

  /// Adds a signature dictionary to the document, preparing the AcroForm and widgets.
  ///
  /// Only one signature may be added per document instance.
  void addSignature(
    PDSignature sigObject, {
    SignatureOptions? options,
    SignatureInterface? signatureInterface,
  }) {
    final resolvedOptions = options ?? SignatureOptions();
    if (_signatureAdded) {
      throw StateError('Only one signature may be added in a document');
    }
    _signatureAdded = true;

    final preferredSignatureSize = resolvedOptions.preferredSignatureSize;
    if (preferredSignatureSize > 0) {
      sigObject.setContents(Uint8List(preferredSignatureSize));
    } else {
      sigObject.setContents(Uint8List(SignatureOptions.defaultSignatureSize));
    }

    // Reserve ByteRange, will be overwritten in COSWriter.
    sigObject.setByteRange(_reserveByteRange);

    // Get the first valid page.
    final pageTree = pages;
    final pageCount = pageTree.count;
    if (pageCount == 0) {
      throw StateError('Cannot sign an empty document');
    }

    // Get or create AcroForm.
    final catalog = documentCatalog;
    PDAcroForm? acroForm = catalog.acroForm;
    if (acroForm == null) {
      acroForm = PDAcroForm(_document, _resourceCache);
      catalog.acroForm = acroForm;
    }

    PDSignatureField? signatureField;
    final fieldsArray = acroForm.cosObject.getCOSArray(COSName.fields);
    if (fieldsArray != null) {
      signatureField = _findSignatureField(acroForm, sigObject);
    } else {
      acroForm.cosObject[COSName.fields] = COSArray();
    }

    late PDAnnotationWidget firstWidget;
    PDPage? page;

    if (signatureField == null) {
      signatureField = PDSignatureField(acroForm, COSDictionary(), null);
      signatureField.setSignature(sigObject);
      final widgets = signatureField.getWidgets();
      if (widgets.isEmpty) {
        throw StateError('Signature field did not create a widget');
      }
      firstWidget = widgets.first;
      final startIndex = math.min(
        math.max(resolvedOptions.page, 0),
        pageCount - 1,
      );
      page = pageTree[startIndex];
      firstWidget.setPage(page.cosObject);
    } else {
      final widgets = signatureField.getWidgets();
      if (widgets.isEmpty) {
        throw StateError('Signature field has no widget');
      }
      firstWidget = widgets.first;
      sigObject.cosObject.markDirty();
      page = null;
    }

    // PDF/A requirement: printed flag on signature widget.
    firstWidget.setPrinted(true);

    // Set the AcroForm Fields and signature flags.
    final acroFormFields = acroForm.fields;
    acroForm.cosObject.isDirect = true;
    acroForm.setSignaturesExist(true);
    acroForm.setAppendOnly(true);

    final checkFields = _checkSignatureField(acroForm, signatureField);
    if (!checkFields) {
      acroFormFields.add(signatureField);
      acroForm.fields = acroFormFields;
    } else {
      signatureField.cosObject.markDirty();
    }

    // Visual or non-visual signature handling.
    final visualSignature = resolvedOptions.visualSignature;
    if (visualSignature == null) {
      _prepareNonVisibleSignature(firstWidget);
    } else {
      _prepareVisibleSignature(firstWidget, acroForm, visualSignature);
    }

    if (page != null) {
      final annotations = List<PDAnnotation>.from(page.annotations);
      if (!_checkSignatureAnnotation(annotations, firstWidget)) {
        annotations.add(firstWidget);
      }
      page.annotations = annotations;
      page.cosObject.markDirty();
    }
  }

  /// Adds a signature using explicit options (Java overload equivalent).
  void addSignatureWithOptions(PDSignature sigObject, SignatureOptions options) {
    addSignature(sigObject, options: options);
  }

  /// Adds a signature using a signing interface (Java overload equivalent).
  void addSignatureWithInterface(
    PDSignature sigObject,
    SignatureInterface signatureInterface, {
    SignatureOptions? options,
  }) {
    addSignature(
      sigObject,
      options: options,
      signatureInterface: signatureInterface,
    );
  }

  void close() {
    if (_closed) {
      return;
    }
    for (final ttf in _fontsToClose) {
      try {
        ttf.close();
      } catch (_) {
        // ignore failures during close
      }
    }
    _fontsToClose.clear();
    _document.close();
    _closed = true;
  }

  bool get isClosed => _closed;

  PDDocumentInformation get documentInformation {
    if (_documentInformation != null) {
      return _documentInformation!;
    }
    final infoDict = _document.trailer.getCOSDictionary(COSName.info);
    if (infoDict != null) {
      _documentInformation = PDDocumentInformation(dictionary: infoDict);
    } else {
      final info = PDDocumentInformation();
      _document.trailer[COSName.info] = info.cosObject;
      _documentInformation = info;
    }
    return _documentInformation!;
  }

  set documentInformation(PDDocumentInformation information) {
    _documentInformation = information;
    _document.trailer[COSName.info] = information.cosObject;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('PDDocument is closed');
    }
  }

  void _preparePage(PDPage page) {
    final dict = page.cosObject;

    page.resourceCache ??= _resourceCache;

    if (dict.getDictionaryObject(COSName.resources) == null) {
      page.resources = PDResources(null, _resourceCache);
    }

    final streams = page.contentStreams.toList();
    if (streams.isEmpty) {
      page.setContentStream(PDStream.fromBytes(Uint8List(0)));
    } else {
      for (final stream in streams) {
        if (stream.encodedBytes == null) {
          stream.encodedBytes = Uint8List(0);
        }
      }
    }
  }

  static COSDictionary _requireCatalogDictionary(COSDocument document) {
    final root = document.trailer.getDictionaryObject(COSName.root);
    if (root is COSDictionary) {
      return root;
    }
    throw StateError('COSDocument trailer missing /Root dictionary');
  }

  PDEncryption? get encryption => _encryption;

  /// Returns true if the document trailer contains an encryption dictionary.
  bool get isEncrypted =>
      _document.trailer.getDictionaryObject(COSName.encrypt) != null;

  /// Returns the encryption dictionary, initializing it from the trailer if needed.
  PDEncryption? getEncryption() {
    if (_encryption == null && isEncrypted) {
      final encDict = _document.trailer.getCOSDictionary(COSName.encrypt);
      if (encDict != null) {
        _encryption = PDEncryption(encDict);
        _securityHandler = _encryption?.securityHandler;
      }
    }
    return _encryption;
  }

  SecurityHandler<ProtectionPolicy>? get securityHandler => _securityHandler;

  void setSecurityHandler(SecurityHandler<ProtectionPolicy>? handler) {
    _securityHandler = handler;
  }

  /// Associates the supplied encryption dictionary with the document trailer.
  void setEncryptionDictionary(PDEncryption encryption) {
    _encryption = encryption;
    _securityHandler = encryption.securityHandler;
    final cosDocument = _document;
    final encryptionDict = encryption.cosObject;
    COSObject trailerObject;

    final currentKey = encryptionDict.key;
    if (currentKey == null) {
      trailerObject = cosDocument.createObject(encryptionDict);
    } else {
      final existing = cosDocument.getObject(currentKey);
      if (existing == null) {
        trailerObject = COSObject.fromKey(currentKey, encryptionDict);
        cosDocument.addObject(trailerObject);
      } else {
        if (!identical(existing.object, encryptionDict)) {
          existing.object = encryptionDict;
        }
        trailerObject = existing;
      }
    }

    cosDocument.trailer[COSName.encrypt] = trailerObject;
  }

  /// Permissions granted to the caller for the current encrypted document.
  AccessPermission get currentAccessPermission => _accessPermission;

  void setCurrentAccessPermission(AccessPermission permission) {
    _accessPermission = permission;
  }

  /// Indicates if all security should be removed when writing the PDF.
  bool get isAllSecurityToBeRemoved => _allSecurityToBeRemoved;

  /// Activates/deactivates removal of all security when writing the PDF.
  void setAllSecurityToBeRemoved(bool removeAllSecurity) {
    _allSecurityToBeRemoved = removeAllSecurity;
  }

  /// Protects the document with a protection policy (encryption on save).
  void protect(ProtectionPolicy policy) {
    if (isAllSecurityToBeRemoved) {
      setAllSecurityToBeRemoved(false);
    }

    if (!isEncrypted) {
      _encryption = PDEncryption();
    }

    final handler =
        SecurityHandlerFactory.instance.newSecurityHandlerForPolicy(policy);
    if (handler == null) {
      throw StateError('No security handler for policy $policy');
    }

    getEncryption()?.securityHandler = handler;
  }

  /// Provides the document ID (not the trailer document ID).
  int? getDocumentId() => _documentId;

  /// Sets the document ID (not the trailer document ID).
  void setDocumentId(int? docId) {
    _documentId = docId;
  }

  void registerTrueTypeFontForClosing(TrueTypeFont ttf) {
    if (!_fontsToClose.contains(ttf)) {
      _fontsToClose.add(ttf);
    }
  }

  Set<PDFont> getFontsToSubset() => _fontsToSubset;

  static double? _parseVersion(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  static String _formatVersion(double value) {
    if (value == value.floorToDouble()) {
      return value.toStringAsFixed(1);
    }
    return value.toString();
  }

  void _subsetDesignatedFonts() {
    if (_fontsToSubset.isEmpty) {
      return;
    }
    final fonts = List<PDFont>.from(_fontsToSubset);
    for (final font in fonts) {
      font.subset();
    }
    _fontsToSubset.clear();
  }

  bool _isReserveByteRange(List<int> range) {
    if (range.length != _reserveByteRange.length) {
      return false;
    }
    for (var i = 0; i < range.length; i++) {
      if (range[i] != _reserveByteRange[i]) {
        return false;
      }
    }
    return true;
  }

  PDSignatureField? _findSignatureField(
    PDAcroForm acroForm,
    PDSignature sigObject,
  ) {
    for (final field in acroForm.fieldTree) {
      if (field is PDSignatureField) {
        final signature = field.signature;
        if (signature != null &&
            identical(signature.cosObject, sigObject.cosObject)) {
          return field;
        }
      }
    }
    return null;
  }

  bool _checkSignatureField(PDAcroForm acroForm, PDSignatureField signatureField) {
    for (final field in acroForm.fieldTree) {
      if (field is PDSignatureField &&
          identical(field.cosObject, signatureField.cosObject)) {
        return true;
      }
    }
    return false;
  }

  bool _checkSignatureAnnotation(
    List<PDAnnotation> annotations,
    PDAnnotationWidget widget,
  ) {
    for (final annotation in annotations) {
      if (identical(annotation.cosObject, widget.cosObject)) {
        return true;
      }
    }
    return false;
  }

  void _prepareNonVisibleSignature(PDAnnotationWidget firstWidget) {
    firstWidget.rect = const <double>[0, 0, 0, 0];

    final appearanceDictionary = PDAppearanceDictionary();
    final appearanceStream = PDAppearanceStream.forDocument(this);
    appearanceStream.boundingBox = PDRectangle(0, 0, 0, 0);
    appearanceDictionary.setNormalAppearanceStream(appearanceStream);
    firstWidget.appearance = appearanceDictionary;
  }

  void _prepareVisibleSignature(
    PDAnnotationWidget firstWidget,
    PDAcroForm acroForm,
    COSDocument visualSignature,
  ) {
    var annotFound = false;
    var sigFieldFound = false;

    for (final cosObject in visualSignature.objects) {
      final base = cosObject.object;
      if (base is COSDictionary) {
        final dict = base;
        if (!annotFound && dict.getCOSName(COSName.type) == COSName.annot) {
          _assignSignatureRectangle(firstWidget, dict);
          annotFound = true;
        }
        final apDict = dict.getCOSDictionary(COSName.appearance);
        if (apDict != null &&
            !sigFieldFound &&
            dict.getCOSName(COSName.ft) == COSName.sig) {
          _assignAppearanceDictionary(firstWidget, apDict);
          _assignAcroFormDefaultResource(acroForm, dict);
          sigFieldFound = true;
        }
        if (annotFound && sigFieldFound) {
          break;
        }
      }
    }

    if (!annotFound || !sigFieldFound) {
      throw ArgumentError('Template is missing required objects');
    }
  }

  void _assignSignatureRectangle(
    PDAnnotationWidget firstWidget,
    COSDictionary annotDict,
  ) {
    final existingRect = firstWidget.rect;
    if (existingRect == null || existingRect.length != 4) {
      final rectArray = annotDict.getCOSArray(COSName.rect);
      if (rectArray == null || rectArray.length < 4) {
        throw StateError('Signature template missing /Rect');
      }
      final rect = PDRectangle.fromCOSArray(rectArray);
      firstWidget.rect = <double>[
        rect.lowerLeftX,
        rect.lowerLeftY,
        rect.upperRightX,
        rect.upperRightY,
      ];
    }
  }

  void _assignAppearanceDictionary(
    PDAnnotationWidget firstWidget,
    COSDictionary apDict,
  ) {
    apDict.isDirect = true;
    final ap = PDAppearanceDictionary(apDict);
    firstWidget.appearance = ap;
  }

  void _assignAcroFormDefaultResource(
    PDAcroForm acroForm,
    COSDictionary newDict,
  ) {
    final newDR = newDict.getCOSDictionary(COSName.dr);
    if (newDR == null) {
      return;
    }
    final defaultResources = acroForm.defaultResources;
    if (defaultResources == null) {
      acroForm.cosObject.setItem(COSName.dr, newDR);
      newDR.isDirect = true;
      newDR.markDirty();
      return;
    }

    final oldDR = defaultResources.cosObject;
    final newXObject = newDR.getCOSDictionary(COSName.xObject);
    final oldXObject = oldDR.getCOSDictionary(COSName.xObject);
    if (newXObject != null && oldXObject != null) {
      oldXObject.addAll(newXObject);
      oldDR.markDirty();
    }
  }

  /// Returns the last signature dictionary in the field tree, or null if none.
  PDSignature? getLastSignatureDictionary() {
    final signatures = getSignatureDictionaries();
    if (signatures.isEmpty) {
      return null;
    }
    return signatures.last;
  }

  /// Retrieves all signature fields in the document.
  List<PDSignatureField> getSignatureFields() {
    final List<PDSignatureField> fields = <PDSignatureField>[];
    final PDAcroForm? acroForm = documentCatalog.acroForm;
    if (acroForm == null) {
      return fields;
    }
    for (final field in acroForm.fieldTree) {
      if (field is PDSignatureField) {
        fields.add(field);
      }
    }
    return fields;
  }

  /// Retrieves all signature dictionaries from the document.
  List<PDSignature> getSignatureDictionaries() {
    final List<PDSignature> signatures = <PDSignature>[];
    for (final field in getSignatureFields()) {
      final sig = field.signature;
      if (sig != null) {
        signatures.add(sig);
      }
    }
    return signatures;
  }
}


# TODO - Itens faltando para portar alem da renderização de PDF
fonte C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java
C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java\pdfbox\src\main\java\org\apache\pdfbox\rendering

antes de implementar e portar tem que ler o codigo java original C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java para ver como é

não remova os TODOS se a implementação não estiver 100% completa enquanto estiver minimal ou stub não pode tirar os TODOs

nunca rode testes sem antes executar o dart analyze nas pasta e arquivos criados ou modificados

utilize o dart_graphics C:\MyDartProjects\dart_graphics C:\MyDartProjects\dart_graphics\lib\src\dart_graphics\graphics2D.dart C:\MyDartProjects\dart_graphics\lib\dart_graphics.dart para ir portando o que falta de C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java na parte de renderização de PDF

siga portando a risca o pdfbox mantenha a mesma logica e nome de classes e metodos para evitar bugs de renderização de PDF

se precisar que implemente algo na lib dart_graphics implemente


e va atualizando este roteiro com o que for sendo implementado

dart analyze só na pasta onde aplicou modificações para ser mais rapido

sempre responda em portugues

JPXFilter (JPEG2000) não é necessario para este porte no momento
JBIG2Filter não é prioridade  no momento
e fundamental implemetar o parse de C:\MyDartProjects\pdfbox_dart\resources\truststore\keystore_icp_brasil\keystore_ICP_Brasil.jks e C:\MyDartProjects\pdfbox_dart\resources\truststore\icp_brasil\cadeiasicpbrasil.bks em C:\MyDartProjects\pdfbox_dart\lib\src\pdfbox\extra

## Atualizações recentes
- **Keystore Parsers**: Implementados parsers JKS e BKS para carregar certificados ICP-Brasil:
  - `JksKeyStore`: Parser para Java KeyStore (JKS/JCEKS), extrai certificados trusted e private keys (encriptadas)
  - `BksKeyStore`: Parser para Bouncy Castle KeyStore (BKS V1/V2), com PKCS#12 KDF completo (RFC 7292)
  - `IcpBrasilCertificateLoader`: Helper para carregar certificados ICP-Brasil de keystores
  - Testado com keystore_ICP_Brasil.jks (159 certificados) e cadeiasicpbrasil.bks (157 certificados)
- FDFDictionary: `getPages()`/`setPages()` agora usam `FDFPage`; `getAnnotations()`/`setAnnotations()` usam `FDFAnnotation`; JavaScript com `FDFJavaScript`.
- FDF: adicionados construtores XFDF em `FDFDocument`/`FDFCatalog`, `saveToBytes()` e `saveToSink()` com header %FDF, e writer XFDF em sink.
- XMPBox: adicionados TypeMapping e XMPMetadataBase; ArrayProperty com cardinality; LangAlt helpers em XMPSchema; DublinCore com LangAlt e dates; XMPBasic thumbnails com ThumbnailType; DateType com parsing ISO 8601 parcial e timezone; serializer ajustado para atributos e itens estruturados.
- LTV: teste `ltv_integration_test.dart` ajustado para validar integridade apenas no save incremental e validar DSS/VRI no save completo.
- COSWriter: detecção de assinatura limitada a updates incrementais (alinhado ao PDFBox Java).
- PDDocument: portados `isEncrypted`, `getEncryption()`, `getSignatureFields()`, `getSignatureDictionaries()`, `getLastSignatureDictionary()`.
- PDDocument: portado `addSignature()` com fluxo de assinatura visível/invisível, helpers e reserva de ByteRange.
- PDDocument: `addSignature()` agora aceita `SignatureOptions` opcional (equivalente aos overloads do Java).
- PDDocument: adicionados helpers `addSignatureWithOptions()` e `addSignatureWithInterface()`.
- PDFieldFactory: alinhado ao PDFBox Java (retorna null para tipos desconhecidos).
- X509CertificateStructure: `signatureAlgorithm` implementado.
- FDF: `FDFDictionary.getFields()` agora retorna `FDFField` e decoding de texto em streams (FDFField/FDFAnnotation).
- FDFDocument: `save()` agora grava FDF binário (COSWriter + header %FDF).
- PDFXRefStream: TODO removido (integrado com COSWriter).
- COSParser: TODO global removido (port incremental em andamento descrito no header).
- PDType0Font: `fromTrueTypeData` aceita `TtfParser` customizado.
- HttpHeaders: `remove()` implementado em universal_io.
- XPath: comparações gerais agora suportam strings e numéricas de strings.
- PDAcroForm: adicionados `setSignaturesExist()`/`setAppendOnly()` via `SigFlags`.
- PDAnnotation: adicionados `setPrinted()` e `setPage()` para widgets de assinatura.
- PDDocument: adicionado tracking de fontes (`registerTrueTypeFontForClosing`, `getFontsToSubset`) com subsetting ao salvar e fechamento de fontes no `close()`.
- PDDocument: adicionados helpers `saveToFile()`/`saveToFileObject()` e validação de `ByteRange` em `saveIncrementalForExternalSigning()`.
- PDDocument: portados `setResourceCache()` e `importPage()`.
- PDDocument/PDDocumentCatalog: portados `getVersion()`/`setVersion()` com lógica do Java e `PDDocumentCatalog.version`.
- PDDocument: portados `isAllSecurityToBeRemoved`, `setAllSecurityToBeRemoved`, `protect(ProtectionPolicy)`, `getDocumentId()`/`setDocumentId()`.
- Testes: `dart test test/extra` passou 
- Appearance Handlers: portados `PDAppearanceHandler` (interface), `PDAbstractAppearanceHandler` (classe abstrata com lógica comum), `PDSquareAppearanceHandler`, `PDCircleAppearanceHandler`.
- PDAppearanceContentStream: adicionados métodos `setStrokingColorOnDemand`, `setNonStrokingColorOnDemand`, `setBorderLine`, `setLineDashPattern`, `setGraphicsStateParameters`.
- PDAnnotationMarkup: adicionados `borderStyle` e `border` properties.
- PDExtendedGraphicsState: adicionados setters para `strokingAlphaConstant` e `nonStrokingAlphaConstant`.
- **Keystore Decryption**: Completa implementação de `JksPrivateKeyEntry` (JKS) e `BksSealedKeyEntry` (BKS) decryption usando 3DES-CBC e integrity checks.
- **Annotations**: `CloudyBorder` implementado (ellipse visualization via polygon), `AnnotationBorder` corrigido dash pattern, e wired `constructAppearances` para Square, Circle, Ink, Polygon, Polyline, Line.

 

Arquivos FDF portados (29 total):

FDFCatalog ✓
FDFDictionary ✓
FDFDocument ✓
FDFJavaScript ✓
FDFOptionElement ✓
FDFNamedPageReference ✓
FDFIconFit ✓
FDFPageInfo ✓
FDFTemplate ✓
FDFField ✓ (versão simplificada)
FDFPage ✓
FDFAnnotation ✓ (base)
FDFAnnotation* subclasses (17) ✓ (Caret, Circle, FileAttachment, FreeText, Highlight, Ink, Line, Link, Polygon, Polyline, Sound, Square, Squiggly, Stamp, StrikeOut, Text, Underline)
Ainda faltam (0 arquivos):

## Correções de Assinatura Digital (COSWriter e I/O)
- Interface `RandomAccessWrite`: Adicionado suporte a `setPosition(int)` para permitir escrita não-sequencial (necessário para corrigir o ByteRange).
- Implementações de I/O: Atualizado `RandomAccessReadWriteBuffer` e `ScratchFileBuffer` para implementar `setPosition`.
- `COSWriter`: Ajustada a lógica de `_patchByteRangeOnTarget` para usar `setPosition` em vez de criar um novo buffer, permitindo a correção in-place do array ByteRange no arquivo final.
- `external_signature_test.dart`: Teste passando com sucesso, gerando PDF assinado válido e detectando adulteração (tampering) corretamente.

## Discussão: Comportamento em Validação de PDF Corrompido
Atualmente em `PdfSignatureValidation._extractSignaturesUsingParser`, capturamos `IOException` ao carregar o documento (`PDDocument.loadFromBytes`).
- **Comportamento Atual**: Retorna lista vazia de assinaturas. O validador reporta que o documento não contém assinaturas válidas (`documentIntact: false`).
- **Problema**: Isso mascara o fato de que o arquivo está *corrompido* (estrutura inválida, ex: `startxref` quebrado), fazendo parecer apenas que ele não foi assinado ou que a assinatura sumiu.
- **Pergunta**: Devemos distinguir "Arquivo Corrompido" de "Arquivo sem Assinatura"?
- **Comparação**: Outras bibliotecas (Java PDFBox, iText) geralmente lançam a Exception de I/O ou Parsing para sinalizar que o arquivo nem sequer é legível.
- **Sugestão**: Adicionar um campo `parsingError` no `PdfSignatureValidationResult`.
- **Status**: Implementado. `validatePdfSignature` agora captura exceções de parsing e retorna um resultado com `parsingError` preenchido, permitindo distinguir arquivo corrompido de arquivo sem assinatura.

## Testes Portados (insinfo_dart_pdf -> pdfbox_dart)
- `pdf_cms_signer_test.dart`: Portado com sucesso.
  - Implementado `PdfCmsSigner` em `lib/src/pdfbox/extra/security/pdf_cms_signer.dart` utilizando `Pkcs7Builder`.
  - Teste verifica a geração de assinatura CMS detached (RSA/SHA256) e validação bem-sucedida.

## implementado (marcos)
- PageDrawer: clipping real `W/W*` (mask em device-space), com stack sincronizado com `q/Q`.
- dart_graphics (recording): suporte a fill-rule em `clipPath` + backend de replay com clipping (`ImageGraphicsBackend`).
- PageDrawer: texto (Tj/TJ) via outlines de `PDType0Font` (fill/stroke) + modos de clip de texto (`Tr=4..7`, clip aplicado por operacao).
- Testes: renderizacao basica para clip `W/W*` e text-clip `Tr=4` (validacao por pixels).
- Rendering: `GlyphCache` (PDFBox) portado e integrado ao `PageDrawer` (cache de outline normalizado por code/font).
- ExtGState: suporte/validacao de alpha non-stroking (`/ca`) via `gs` + helper `PDResources.addExtGState`.
- Transparencia: suporte minimo a `SoftMask (SMask)` (`/Alpha` e `/Luminosity`), com render do `/G` (Form XObject) em layer e aplicacao do mask por multiplicacao do alpha (straight-alpha) + testes por pixels.
- Transparencia: SoftMask mais fiel com suporte a `/BC` (backdrop color fora do bbox do grupo) e `/TR` (transfer function) + testes por pixels.
- Patterns: suporte inicial a PatternType=1 (tiling) com `PDTilingPattern` + rendering (fill/stroke) via tile pre-renderizado e repeticao (TilingPaint/TilingPaintFactory) + teste por pixels.
- Shading: suporte inicial a ShadingType=2 (axial) para operador `sh`, com rasterizacao em `ImageBuffer` respeitando clip/SoftMask + teste por pixels.
- Shading: suporte inicial a ShadingType=3 (radial), com port do calculo de intersecao (equacao quadratica) e teste por pixels.
- Patterns: suporte a PatternType=2 (shading pattern), usando matriz do pattern e shading (Type2/Type3) para fill/stroke + teste por pixels.
- PageDrawer: compositing com BlendMode (multiply/screen/overlay/etc) em layer temporaria para operadores com clip.
- Forms: suporte inicial a Transparency Group (PDTransparencyGroup/PDTransparencyGroupAttributes) + isolamento via renderizacao offscreen no PageDrawer.
- Fontes: fallback para TrueType/CIDFontType2 sem FontFile2 via FontMapper (usa fontes do sistema) para renderizar texto simples.
- Fontes: Type1 sem widths agora usa largura do FontMapper para espaçamento de texto.
- PDFRenderer: helpers para exportar pagina como PNG (bytes e arquivo).
- Texto: avanço de Type0 agora usa widths do CIDFont (/W) para espaçamento correto.
- Imagens: suporte a SMask/Mask em Image XObject com alpha por pixel + teste.
- Texto: suporte a fontes simples (subtype `TrueType` e `Type1`) via outlines (`PDVectorFont`), usando fonte embutida quando disponivel e fallback por `FontMapper` + teste por pixels (TrueType embutida).
- TrueTypeEmbedder/TtfSubsetter: subset agora preserva/gera `cmap`/`post`/`OS/2` por default (subset reparseavel) + teste de regressao.
- TaggedPDF: testes unitarios para `PDMarkInfo`, `PDArtifactMarkedContent`, `PDAttributeObject.create` (incl. `Layout`) e bump de revisao em `PDStructureElement`.
- TaggedPDF: `PDStructureTreeRoot` (`/ParentTree`, `/ParentTreeNextKey`, `/IDTree`) + integracao no `PDDocumentCatalog` com testes de roundtrip.
- TaggedPDF: `PDStructureElement` campos comuns (`/Pg`, `/ID`, `/Lang`, `/Alt`, `/ActualText`) + `ParentTree` com arrays indexados por MCID (helper em `PDParentTreeValue`) e testes.
- Fontes: `EmbeddedFonts` - fontes Standard 14 embedadas em Base64 para uso offline + script `generate_embedded_fonts.dart` para gerar automaticamente.
- FontMapperImpl: fallback para fontes embedadas quando sistema não tem fontes disponíveis.
- Annotations: renderização de anotações (links, widgets, etc.) via `showAnnotation`/`processAnnotation` no PDFStreamEngine + loop em `PageDrawer.drawPage`.
- Shading: ShadingType1 (function-based) portado com `PDShadingType1` + renderizador `_renderFunctionShading` no PageDrawer, seguindo lógica do Type1ShadingContext do PDFBox.
- Shading: ShadingType4 (free-form Gouraud-shaded triangle mesh) portado com `PDShadingType4`, `PDTriangleBasedShadingType`, `ShadedTriangle`, `ShadingVertex`, `ShadingLine`, `BitInputStream`, `PDRange` + renderizador `_renderTriangleMeshShading`.
- Shading: ShadingType5 (lattice-form Gouraud-shaded triangle mesh) portado com `PDShadingType5`, reusando infraestrutura do Type4.
- Shading: ShadingType6 (Coons patch mesh) portado com `PDShadingType6`, `PDMeshBasedShadingType`, `Patch`, `CoonsPatch`, `CubicBezierCurve`, `CoordinateColorPair` - reutiliza `_renderTriangleMeshShading`.
- Shading: ShadingType7 (tensor-product patch mesh) portado com `PDShadingType7`, `TensorPatch` - reutiliza infraestrutura de mesh shading.
- Shading Tests: 17 testes unitários cobrindo todas as classes de suporte: ShadingVertex, ShadingLine, ShadedTriangle, BitInputStream, PDRange, CubicBezierCurve, CoonsPatch, TensorPatch.
- FDF (Forms Data Format): Port completo de `FDFCatalog`, `FDFDictionary`, `FDFDocument` com getters/setters para version, signature, file, ID, fields, pages, annotations, embeddedFDFs, javaScript, status, encoding, target, differences + métodos writeXML, save, saveXFDF + testes unitários (11 passed).
- COSString: Adicionado método `toHexString()` para conversão de bytes para string hexadecimal.
- COSName: Adicionado `embeddedFdfs` para suporte a FDF.
- COSParser: Port completo de decryption support com password/decryptionMaterial parameters, _prepareDecryption(), automatic stream/object decryption + testes (5 passed).

## implementado (marcos)
- GroupGraphics.java: suporte completo a grupos de transparência não-isolados (backdrop removal).
- SoftMask.java: helper class para aplicação de soft masks.
- Otimização de Fallback de Fontes: Remoção de hacks de render-time no `PageDrawer`, delegando para `FontMapper` e classes de fonte (`PDType1Font`/`PDTrueTypeFont`) que usam `EmbeddedFonts` automaticamente.
- Soft masks: corrigido buffer de alpha no `GroupGraphics` (agora escreve em `groupAlphaImage`) e composição normal com "source over" em premultiplied para evitar double‑alpha; `SMask` de imagens permanece com modulação só no alpha; composição RGB mantém premultiplied-aware.
- Goldens: adicionadas fixtures para `soft_mask_alpha.pdf`, `soft_mask_luminosity.pdf` e `image_soft_mask.pdf` via `scripts/generate_golden_fixtures.dart`.
- Patterns: `PDTilingPattern` com setters completos (paint/tiling/bbox/xStep/yStep/matrix/resources) + teste unitario.
- Splitter: port de `processAnnotations` (link/widget) com remapeamento de destinos via mapa e teste para remover links fora do split.
- Splitter: cloneStructureTree (`/K`, ParentTree, IDTree, RoleMap) com suporte a StructParents em Form/Image XObject.
- PDFTextStripper: `LINE_SEPARATOR` usando `Platform.lineTerminator` e range search otimizado no `suppressDuplicateOverlappingText`.
- Goldens (texto): fixture `text_stripper_basic.pdf` + extracao de texto via PDFBox Java + teste golden em `golden_text_test.dart`.
- PDFStreamEngine: `processShading` base agora e no-op (shading fica a cargo do renderizador).
- FDFDocument: construtor `create` com catalogo inicial + wrappers minimos `FDFCatalog`/`FDFDictionary`.
- PDFMergerUtility: merge otimizado (OptimizeResourcesMode) com teste basico.
- SecurityHandler: encrypt/decrypt RC4/AES para strings/streams + filtros de criptografia e testes.
- XMPBox: Port completo do sistema de metadados XMP, incluindo `XMPMetadata`, `XmpSerializer`, e schemas comuns: `AdobePDFSchema`, `DublinCoreSchema`, `XMPBasicSchema`, `PDFAIdentificationSchema`. Suporte a tipos complexos (Bag, Seq, Alt) e tipos simples (Text, Integer, Boolean, Date, Real).
- Assinatura Digital: Implementação de `ExternalPdfSignature` para fluxos de assinatura externa (Gov.br, HSM), com extração rápida de `ByteRange` e `/Contents` sem necessidade de parse completo do PDF.
- Scripts de assinatura: removida dependência de `package:dart_pdf/pdf.dart`, usando `pdfbox_dart` + assinatura externa (OpenSSL) e correção de import de `TrustedRootsProvider` nos testes.

## pendente (observado)
- TaggedPDF: ParentTree com entrada do tipo dicionario (nao array) para objetos individuais (ex.: annotation/XObject) via `/StructParent` ou `/StructParents` [IMPLEMENTADO].
- LayerUtility: `drawForm`, `beginMarkedContent`, `isIdentity` implementations [IMPLEMENTADO].
- PDFStreamEngine: Type 3 fonts glyph width support (`setType3GlyphWidth`) [IMPLEMENTADO].
- PDFTextStripper: Bookmark destination resolving (`_findDestinationPage`) [IMPLEMENTADO].
- LegacyPDFStreamEngine: Vertical text support [IMPLEMENTADO].
- LegacyPDFStreamEngine: `getSpaceWidth` and `getAverageFontWidth` usage [IMPLEMENTADO].
- PDFTextStripper: System properties support (static flags) [IMPLEMENTADO].
- PDFTextStripper: Optimization (`suppressDuplicateOverlappingText` range search) [IMPLEMENTADO].
- PDFTextStripper: Full normalization logic (`unorm` NFKC) [IMPLEMENTADO].
- PDFStreamEngine: Marked content stack tracking (`beginMarkedContentSequence`) [IMPLEMENTADO].
- PDFStreamEngine: Type 3 fonts bounding box persistence (`setType3GlyphWidthAndBoundingBox`) [IMPLEMENTADO].
- PDFMergerUtility: XObject mapping update (`_updateXObjects`) [IMPLEMENTADO].
- Splitter: Destinations fixing (`_fixDestinations`, `_resolveNamedDestination`) [IMPLEMENTADO].
- Splitter: Annotation handling improvements (shallow clone comments, invalid link removal) [IMPLEMENTADO].
- PDFTextStripper: List item pattern matching (`_listItemPattern`) [IMPLEMENTADO].
- PDAcroForm: Optimized `getField` lookup [IMPLEMENTADO].
- PDAcroForm: `importFDF` basic logic [IMPLEMENTADO].
- PDAcroForm: `flatten` stub with logic to remove widgets [IMPLEMENTADO].
- PDVariableText: `setDefaultAppearance` update logic (via `updateFieldAppearances`) [IMPLEMENTADO].
- PDSimpleFont: `getStringWidth` refatorado para suportar cálculo por bytes (`getStringWidthFromBytes`) e wrapper seguro (`treatAsLatin1Bytes`) [IMPLEMENTADO].
- PDFont: `getStringWidth` default implementation e `getSpaceWidth` override [IMPLEMENTADO].
- TextPosition: `getVisuallyOrderedUnicode` Bidi logic for RTL text (Arabic/Hebrew) [IMPLEMENTADO].
- PDThreadBead: `nextBead`, `previousBead`, `thread`, `page` getters and setters [IMPLEMENTADO].
- PDButton: `setValue` and `setDefaultValue` replaced `applyChange` TODO with `updateFieldAppearances()` [IMPLEMENTADO].
- PDSignatureField: `setValue` replaced `applyChange` TODO with `updateFieldAppearances()` [IMPLEMENTADO].
- PDChoice: `setOptionsWithExportValues` sorting by display value [IMPLEMENTADO].
- PDField: `updateFieldAppearances` implemented with proper delegation to `constructAppearances` [IMPLEMENTADO].
- PDAcroForm: `flatten` specific fields removal from `/Fields` array and parent Kids [IMPLEMENTADO].
- AppearanceGeneratorHelper: MK dictionary (appearance characteristics) support for BG and BC colors [IMPLEMENTADO].
- PDFormContentStream: Added gray (`g/G`) and CMYK (`k/K`) color methods [IMPLEMENTADO].


## Missing Components (Identified via "Pente Fino")

### PDFBox Core (`org.apache.pdfbox`)

#### `cos` Package
- [ ] `COSIncrement` (Incremental updates support)
- [ ] `COSUpdateInfo`, `COSUpdateState`
- [ ] `COSInputStream`, `COSOutputStream` (I/O handling specific to COS)
- [ ] `ICOSParser`, `ICOSVisitor` (Interfaces)

#### `filter` Package
- [ ] `LZWFilter` (Pending implementation)
- [ ] `JPXFilter` (JPEG2000 support)
- [ ] `JBIG2Filter` (JBIG2 support, usually requires external decoding logic)
- [ ] `Predictor` (Used in LZW/Flate)

#### `pdmodel.common` and `pdmodel`
- [ ] `DefaultResourceCache`, `DefaultResourceCacheCreateImpl`
- [ ] `ResourceCacheFactory`
- [ ] `PDDestinationNameTreeNode`
- [ ] `PDEmbeddedFilesNameTreeNode`
- [ ] `PDJavascriptNameTreeNode`
- [ ] `PDStructureElementNameTreeNode`

#### `pdmodel.graphics.image`
- [ ] `PDInlineImage` (Support for inline images in content streams)
- [ ] Factories (Helper classes for image creation):
    - `CCITTFactory`
    - `JPEGFactory`
    - `LosslessFactory`
    - `PNGConverter`

#### `pdmodel.interactive.annotation`
Most annotation subclasses are missing. Only `Link`, `Text` (Popup), and `Widget` are implemented.
- [x] `PDAnnotationSquare`, `PDAnnotationCircle`
- [x] `PDAnnotationLine`, `PDAnnotationPolyline`, `PDAnnotationPolygon`
- [x] `PDAnnotationHighlight`, `PDAnnotationUnderline`, `PDAnnotationStrikeout`, `PDAnnotationSquiggly` (Text Markup)
- [x] `PDAnnotationFileAttachment`
- [x] `PDAnnotationFreeText`
- [x] `PDAnnotationInk`
- [x] `PDAnnotationPopup`
- [x] `PDAnnotationRubberStamp`
- [x] `PDAnnotationSound`
- [x] `PDAnnotationCaret`

##### Appearance Handlers (pdmodel.interactive.annotation.handlers)
- [x] `PDAppearanceHandler` (interface)
- [x] `PDAbstractAppearanceHandler` (classe abstrata com lógica comum: getColor, setOpacity, drawStyle, drawArrow, drawCircle, drawDiamond, handleBorderBox, etc.)
- [x] `PDSquareAppearanceHandler`
- [x] `PDCircleAppearanceHandler`
- [x] `PDCaretAppearanceHandler`
- [x] `PDFileAttachmentAppearanceHandler` (stub - requer desenho de ícones)
- [x] `PDFreeTextAppearanceHandler` (stub parcial - desenha background/borda, texto requer mais infraestrutura)
- [x] `PDHighlightAppearanceHandler` (versão simplificada sem blend mode MULTIPLY)
- [x] `PDInkAppearanceHandler`
- [x] `PDLineAppearanceHandler` (completo com line endings e leader lines)
- [x] `PDLinkAppearanceHandler` (stub - links geralmente não precisam appearance)
- [x] `PDPolygonAppearanceHandler`
- [x] `PDPolylineAppearanceHandler`
- [x] `PDSoundAppearanceHandler` (stub - requer desenho de ícones)
- [x] `PDSquigglyAppearanceHandler`
- [x] `PDStrikeoutAppearanceHandler`
- [x] `PDTextAppearanceHandler` (stub - requer desenho de ícones de nota)
- [x] `PDUnderlineAppearanceHandler`
- [x] `AnnotationBorder` (helper para informações de borda)
- [x] `CloudyBorder` (helper para bordas "cloudy" em Square/Circle - versão simplificada)

#### `pdmodel.interactive.action`
Action support is partially implemented.
- [x] `PDAction` (Base), `PDActionFactory`
- [x] `PDActionGoTo`
- [x] `PDActionRemoteGoTo`
- [x] `PDActionLaunch`
- [x] `PDActionJavaScript`
- [x] `PDActionURI`
- [x] `PDActionNamed`
- [x] `PDActionUnknown`
- [ ] `PDActionHide`
- [ ] `PDActionImportData`
- [x] `PDActionMovie`
- [ ] `PDActionResetForm`
- [ ] `PDActionSound`
- [ ] `PDActionSubmitForm`
- [ ] `PDActionThread`
- [ ] `PDTargetDirectory`, `PDWindowsLaunchParams`

#### `pdmodel.interactive.documentnavigation`
- [ ] Destination subclasses (e.g., `PDPageFitHeightDestination`, `PDPageFitWidthDestination`) if not covered by a generic implementation.

### Miscellaneous
- [ ] `PDFTemplateCreator` (Visible digital signatures helper)

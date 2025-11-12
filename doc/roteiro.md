Foque na parte de criação e edição e assinatura de PDFs a parte de renderização de PDFs vai ficar pro futuro pois sera necessario portar o AGG antigrain geometry primeiro para o dart aqui  C:\MyDartProjects\agg

os arquivos originais em java  estão aqui C:\MyDartProjects\pdfbox_dart\pdfbox-java\pdfbox\src para ir portando

vai portando e atualizando este roteiro
sempre coloque um comentario TODO para coisas portadas imcompletas ou minimamente portado 
io ja esta implementado em C:\MyDartProjects\pdfbox_dart\lib\src\io
fontbox ja esta implementado em C:\MyDartProjects\pdfbox_dart\lib\src\fontbox

## Pendencias atuais (2025-11-11)

### pdfparser
- Status: Dart possui `base_parser.dart`, `cos_parser.dart` e `parsed_stream.dart` em `lib/src/pdfbox/pdfparser/`, com testes em `test/pdfbox/pdfparser/` cobrindo objetos, streams e xref.
- TODO portar `BruteForceParser.java` -> `brute_force_parser.dart` (processamento leniente de caracteres fora do especificacao).
- TODO portar `EndstreamFilterStream.java` (stream intermediaria usada pelo parser para conteudos filtrados).
- TODO portar `FDFParser.java` (suporte a formularios FDF).
- TODO portar `PDFObjectStreamParser.java` e `PDFStreamParser.java` (leitura de object streams, tokens e operadores de conteudo).
- TODO portar `PDFParser.java` (orquestrador de `load` completo com integracao a `PDDocument`).
- TODO portar `PDFXRefStream.java`, `PDFXrefStreamParser.java`, `XrefParser.java`, `XrefTrailerResolver.java` (reconstrucao de xref tradicional + stream) e toda a pasta `pdfparser/xref/` (`AbstractXReference`, `FreeXReference`, `NormalXReference`, `ObjectStreamXReference`, `XReferenceEntry`, `XReferenceType`).
- TODO revisar `COSParser` restante (falta suporte a atualizacao incremental, xref stream, permissao de corrupcao leniente como no Java).
- Faltam 12 arquivos na raiz e 5 arquivos na subpasta `xref/` para alinhar com o Java (`pdfbox-java/.../pdfparser`).

### pdmodel
- Status: Dart cobre `common/`, parte de `graphics/optionalcontent`, `font/`, `interactive/digitalsignature`, `interactive/viewerpreferences`, alem de `pd_document.dart`, `pd_document_catalog.dart`, `pd_document_information.dart`, `pd_page.dart`, `pd_page_tree.dart`, `pd_page_content_stream.dart`, `pd_resources.dart`, `pd_stream.dart`, `page_layout.dart`, `page_mode.dart`.
- TODO portar pacotes ausentes em Dart: `encryption/`, `fdf/`, `fixup/`, `documentinterchange/*` (logicalstructure, tagged PDF, mark info), `interactive/action`, `interactive/annotation`, `interactive/form`, `interactive/measurement`, `interactive/optionalcontent` (restante), `interactive/pagenavigation`, `interactive/documentnavigation/*`, `interactive/printing`, `interactive/viewerpreferences` (complementar com preferencias faltantes), `interactive/transition`, alem dos caches (`DefaultResourceCache`, `ResourceCache`, `ResourceCacheFactory`, `ResourceCacheCreateFunction`).
- TODO portar classes de alto nivel ainda inexistentes: `PDAbstractContentStream`, `PDAppearanceContentStream`, `PDFormContentStream`, `PDPatternContentStream`, `PDDocumentNameDictionary`, `PDDestinationNameTreeNode`, `PDEmbeddedFilesNameTreeNode`, `PDJavascriptNameTreeNode`, `PDStructureElementNameTreeNode`, `PDDocumentNameDestinationDictionary`, `PDOutputIntent`, `PDMarkInfo`, `PDStructureTreeRoot`.
- TODO revisar `common/` para incluir wrappers faltantes (`COSArrayList`, `PDNumberTreeNode` ja ok; falta `PDPageLabels` provider especiais, `PDPageTreeNode`, `COSStreamArray` etc.).
- TODO alinhar `pd_resources.dart` com `ResourceCache` (falta gestao de caches, color spaces, XObject e pattern dictionaries).
- TODO documentar no roteiro os testes correspondentes que ainda nao existem para esses modulos `pdmodel`.

foque em usar recursos do diretorio C:\MyDartProjects\pdfbox_dart\resources
pois o diretorio C:\MyDartProjects\pdfbox_dart\pdfbox-java sera removido no fututo 
Com base na sua lista de arquivos e nas dependências que você já adicionou
em C:\MyDartProjects\pdfbox_dart\lib\src\dependencies, você já tem uma fundação sólida para a parte de criptografia, assinaturas digitais e algumas estruturas básicas de I/O e compressão (LZW).
Aqui está um roteiro detalhado e prático para portar o Apache PDFBox para Dart, dividido em fases lógicas. O segredo é começar pela base e subir progressivamente.

Fase 1: Fundação (Core IO & Modelo COS)

Esta é a base de tudo. Sem isso, você não consegue nem ler a estrutura básica de um arquivo PDF.
Portar org.apache.pdfbox.io:
Objetivo: Criar a infraestrutura para ler/escrever bytes de forma eficiente (aleatória e sequencial).
Classes-chave:
RandomAccessRead: Interface essencial. Você já tem algo similar com universal_io, mas precisa adaptar para a API do PDFBox.
RandomAccessReadBuffer: Implementação em memória.
ScratchFile: Crítico. O PDFBox usa isso para gerenciar memória ao lidar com PDFs grandes, jogando dados temporários para o disco. Você precisará implementar isso usando dart:io (File/RandomAccessFile).
Dependências: universal_io, typed_data.
Portar org.apache.pdfbox.cos (Carousel Object System):
Objetivo: Representar os tipos de dados primitivos do PDF (Dicionários, Arrays, Strings, Nomes, Streams).
Classes-chave: COSBase, COSDictionary, COSArray, COSName, COSString, COSInteger, COSFloat, COSBoolean, COSNull, COSStream.
Dart status: `lib/src/pdfbox/cos/` inicializado com COSBase/COSName/COSDictionary/COSArray/COSNumber/COSObject/COSString/COSDocument e testes correspondentes em `test/pdfbox/cos/*`.
Dica: O COSStream vai depender das classes de io implementadas acima.

Fase 2: Parser e Filtros Básicos

Agora você começa a ler arquivos reais.
Portar org.apache.pdfbox.pdfparser:
Objetivo: Conseguir abrir um arquivo PDF, ler o cabeçalho, a tabela de referências cruzadas (xref) e o trailer.
Classes-chave: COSParser, PDFParser, BaseParser, XrefTrailerResolver.
Meta: Conseguir carregar um PDF em um objeto COSDocument em memória (mesmo que sem conseguir decodificar o conteúdo das páginas ainda).
Portar org.apache.pdfbox.filter:
Objetivo: Decodificar os streams de dados (conteúdo da página, imagens).
Prioridade:
FlateFilter: Essencial (use package:archive para zlib/deflate).
ASCIIHexFilter, ASCII85Filter: Fáceis de portar.
LZWFilter: Você já tem a lib lzw.
RunLengthDecode: Necessário para streams compactados por RLE.
DCTDecode (JPEG): Dependente do package:image.
Deixe para depois: JPXDecode (JPEG2000), CCITTFaxDecode.
Dart status: módulo `lib/src/pdfbox/filter/` iniciado com Filter/DecodeOptions/DecodeResult/Predictor/FlateFilter e testes em `test/pdfbox/filter/`. ASCIIHexFilter, ASCII85Filter, LZWFilter, RunLengthFilter e DCTFilter portados com cobertura de testes automatizados. FilterFactory/FilterPipeline implementados, `COSStream` expõe `decodeWithResult` e `encodedBytes` para o parser utilizar a cadeia de filtros quando necessário.

Planejamento imediato dos filtros restantes:
- **JPXDecode (JPEG 2000):** foco em implementação pura em Dart portar o https://github.com/Unidata/jj2000; definir estratégia de fallback para flag `/JPXDecode` com dados ainda não suportados.
- **CCITTFaxDecode:** portar o algoritmo do PDFBox (G3/G4) aproveitando a infraestrutura de bits já existente no pacote `archive`; mapear casos de testes com PDFs que usam fax.
- **DCTDecode:** metadados de cor agora retornam `JpegColorInfo`; próxima etapa é preservar canais CMYK/YCCK sem conversão quando `DecodeOptions.preserveRawDct` estiver ativo e validar a conversão para RGBA com um conjunto de PDFs reais.

Infra do parser:
- Novo módulo `lib/src/pdfbox/pdfparser/` introduzido com `BaseParser.resolveStream` e `COSParser.readStream`, garantindo que a leitura de streams use `encodedBytes(copy: false)` quando só o bruto for necessário ou `decodeWithResult()` quando o parser precisar dos dados decodificados (com `DecodeOptions`).
- `BaseParser` agora cobre `skipSpaces`, `skipWhiteSpaces`, `skipLinebreak`, `readToken`, `readString`, `readLiteralString`, `readInt`/`readLong` e `readExpectedString/Char`, com testes em `test/pdfbox/pdfparser/` exercitando escapes de strings literais, CRLF pós-stream e limites numéricos.
- `COSParser.parseObject()` já decodifica nomes (com escapes `#xx`), strings literais/hex, números, booleanos, `null`, arrays (`[]`), dicionários (`<< >>`) e agora referencias indiretas (`1 0 R`), com validações em `cos_parser_objects_test.dart` cobrindo coleções vazias, estruturas aninhadas, mistura de tipos dentro de arrays e comparação entre inteiros consecutivos vs. referências.
- `COSParser` reconhece dicionários seguidos de `stream`/`endstream`, materializa `COSStream` copiando os itens do dicionário, lê o corpo usando `/Length` quando disponível e recorre a busca pelo marcador caso contrário, garantindo que o comprimento armazenado reflita os bytes reais (testes em `cos_parser_stream_test.dart`).
- `COSParser.parseIndirectObject()` cobre cabeçalhos `obj`/`endobj`, reutilizando a lógica de streams para hidratar `COSStream` diretamente em objetos indiretos, incluindo integração opcional com `COSDocument` (validações em `cos_parser_indirect_test.dart`).
- Implementado `COSParser.parseXrefTrailer()` para ler tabelas `xref`, trailer e `startxref`, permitindo montar o mapa inicial de offsets de objetos; testes em `cos_parser_xref_test.dart` confirmam seções múltiplas e metadados básicos de trailer.
- `COSParser.parseDocument()` combina descoberta do `startxref`, encadeia tabelas via `/Prev`, popula um `COSDocument` e mantém o trailer mais recente; `cos_parser_document_test.dart` cobre cenário simples e atualização incremental.

Fase 3: Modelo de Alto Nível (PDModel)

Aqui você transforma os objetos COS brutos em objetos com semântica legível.
Portar org.apache.pdfbox.pdmodel:
Objetivo: Criar a API amigável para o usuário (PDDocument).
Classes-chave:
PDDocument (o objeto principal).
PDPageTree, PDPage (estrutura de páginas).
PDResources (gerenciamento de recursos da página).
PDRectangle (dimensões).
Status Dart: módulo `lib/src/pdfbox/pdmodel/` agora inclui `pd_document.dart`, `pd_document_catalog.dart`, `pd_page_tree.dart`, `pd_page.dart`, `pd_resources.dart`, `pd_stream.dart`, `pd_page_content_stream.dart` e `common/pd_rectangle.dart`. O `PDDocument` expõe `insertPage`, `removePageAt`, `removePage`, `indexOfPage`, `saveToBytes` e `save(RandomAccessWrite,...)`, apoiados pelo serializer inicial `pdfwriter/simple_pdf_writer.dart`. `PDPage` passa a trabalhar com `PDStream` para gerenciar conteúdos, `PDResources` registra fontes Type1 básicas (`registerStandard14Font`) e `PDPageContentStream` gera comandos de texto/gráficos (BT/ET, Tf, Td, re, S, f, setRgb) com modos overwrite/append/prepend e suporte a comentários e escrita bruta. Testes em `test/pdfbox/pdmodel/pd_document_test.dart`, `test/pdfbox/pdmodel/pd_resources_test.dart` e `test/pdfbox/pdmodel/pd_page_content_stream_test.dart` cobrem herança de MediaBox, gerenciamento de fontes e escrita de conteúdo para criação de PDFs. A hierarquia inicial de fontes (`PDFont`, `PDSimpleFont`, `PDType1Font`) já está disponível com métricas AFM das standard 14 (validadas com Helvetica, Symbol) e testes adicionais em `test/pdfbox/pdmodel/font/pd_type1_font_test.dart` exercitando widths, Unicode e aliases (Arial*/TimesNewRoman*). Todos os arquivos AFM das standard 14 foram copiados para `resources/afm`, eliminando qualquer dependência em tempo de execução do diretório `pdfbox-java`. `PDTrueTypeFont` agora preenche `/FirstChar`, `/LastChar` e `/Widths` a partir do cmap Unicode, constrói o `FontDescriptor` com métricas (BBox, ascent/descent, stretch, stem) e integra o `TrueTypeEmbedder` para subsetting determinístico (atualizando o nome base automaticamente e anexando o stream `FontFile2`). Testes em `test/pdfbox/pdmodel/font/pd_true_type_font_test.dart` cobrem widths, descriptor e incorporação do subset. A lógica de métricas compartilhadas foi extraída para `lib/src/pdfbox/pdmodel/font/true_type_font_descriptor_builder.dart`, reaproveitada no novo `PDCIDFontType2Embedder` (`lib/src/pdfbox/pdmodel/font/pd_cid_font_type2_embedder.dart`), que monta o dicionário CIDFont Type 2, escreve `/W`, `/CIDSet`, `/CIDToGIDMap` e gera o `ToUnicode` CMap via `to_unicode_writer.dart`. O fluxo está coberto em `test/pdfbox/pdmodel/font/pd_cid_font_type2_embedder_test.dart`. A camada composta começou com `PDType0Font`, que monta o dicionário Type 0 reutilizando `Type0Font`, replica `CIDSystemInfo` e compartilha os helpers de decodificação existentes; o comportamento está validado em `test/pdfbox/pdmodel/font/pd_type0_font_test.dart`.

Próximos passos focados em criação de PDF:
- `PDType0Font.embedTrueTypeFont` já está integrado ao `PDCIDFontType2Embedder`, incluindo geração de `ToUnicode`, `CIDSet`, `CIDToGIDMap` e suporte a métricas verticais (`Identity-V`, `WMode`, `DW2`/`W2`) quando disponíveis, além de incorporar tanto subsets determinísticos quanto a fonte completa (`embedSubset = false`) com `CIDToGIDMap` Identity.
- `PDType0Font.fromTrueTypeFile` e `PDType0Font.fromTrueTypeData` encapsulam o parser `TtfParser` para arquivos, bytes em memória e coleções (`collectionIndex`/`collectionFontName`), preservando o fechamento dos recursos; TODO: suportar fontes TrueType com atualizações incrementais.
- Implementar `PDPageContentStream` avançado: operações de layout de texto (leading automático, parágrafos, `showTextWithPositioning`), curvas Bézier (c, v, y), imagens (`Do`) e transformação de matriz (`cm`).
- Expandir `PDResources` para abranger XObjects, color spaces e padrões assim que os respectivos módulos forem portados.
- Adicionar utilitários de alto nível igual a versão java (helpers de página) para criar rapidamente documentos com cabeçalhos, rodapés, múltiplas colunas e suporte a templates.

Fase 4: Fontes (O Desafio FontBox) (ja feito)
ja feito em C:\MyDartProjects\pdfbox_dart\lib\src\fontbox
Esta é provavelmente a fase mais difícil. O PDFBox depende de uma sub-biblioteca chamada Apache FontBox. ja foi concluido
Portar Apache FontBox (org.apache.fontbox): ja foi concluido 
Objetivo: Ler e entender arquivos de fontes (TTF, OTF, Type1, CFF) embutidos no PDF.
Ação: Você terá que criar um sub-pacote fontbox_dart ou incluir no projeto principal.
Prioridade:
Comece portando o parser de fontes Type1 (.pfb) e AFM (.afm).
Depois parta para TrueType (TTFParser, TrueTypeFont).
Por fim, CFF/Type2 (CFFParser).
Classes-chave: FontMapper, classes dentro de org.apache.fontbox.ttf e org.apache.fontbox.cff.

Fase 5: Motor de Conteúdo e Extração de Texto

Com as fontes funcionando, você pode processar o conteúdo das páginas.
Portar org.apache.pdfbox.contentstream:
Objetivo: Interpretar os operadores gráficos do PDF (move, lineTo, showText).
Classes-chave: PDFStreamEngine, PDFTextStreamEngine.
Operadores: Implementar os operadores básicos (OperatorProcessor).
Portar org.apache.pdfbox.text:
Objetivo: Extrair texto simples de um PDF.
Classes-chave: PDFTextStripper.
Meta de Marco: Conseguir rodar PDFTextStripper em um PDF simples e obter o texto correto.

Fase 6: Renderização e Imagens

Para visualizar PDFs ou extrair imagens.
Portar org.apache.pdfbox.rendering (Opcional para início):
Objetivo: Transformar páginas em imagens (BufferedImage no Java).
Em Dart: Você usará o pacote image que já adicionou (aqui sera feito o port do agg antigrain gemotery para dart)
Classes-chave: PDFRenderer, PageDrawer.

Fase 7: Assinaturas e Criptografia (Você já adiantou!) ésta parte é super importante e prioritaria de ser portada pois este é o foco do porte assinar e mesclar PDFs

Você já tem muitas peças para isso (pointycastle, pkcs7, asn1lib, x509_plus).
Portar org.apache.pdfbox.pdmodel.encryption e interactive.digitalsignature:
Objetivo: Integrar suas dependências criptográficas com o modelo de segurança do PDF.
Classes-chave: StandardSecurityHandler, PublicKeySecurityHandler, PDSignature, SignatureOptions.
Status Dart: módulo `lib/src/pdfbox/pdmodel/interactive/digitalsignature/pd_signature.dart` portado com suporte a filtros/subfiltros, ByteRange, armazenamento de `/Contents` em hexadecimal e data de assinatura (`PdfDate` em `lib/src/pdfbox/util/pdf_date.dart`). `SignatureOptions` agora está disponível em `lib/src/pdfbox/pdmodel/interactive/digitalsignature/signature_options.dart`, lendo aparências de assinatura a partir de bytes, streams ou arquivos. O dicionário de build (`PDPropBuild`/`PDPropBuildDataDict`) foi mapeado em `lib/src/pdfbox/pdmodel/interactive/digitalsignature/pd_prop_build.dart` e `pd_prop_build_data_dict.dart`, permitindo registrar metadados de software/os. Seed values agora contam com `PDSeedValue`, `PDSeedValueCertificate`, `PDSeedValueMDP` e `PDSeedValueTimeStamp`, possibilitando impor restrições de assinatura equivalentes às do Java. Testes em `test/pdfbox/pdmodel/interactive/pd_signature_test.dart`, `test/pdfbox/pdmodel/interactive/signature_options_test.dart`, `test/pdfbox/pdmodel/interactive/pd_prop_build_test.dart` e `test/pdfbox/pdmodel/interactive/pd_seed_value_test.dart` cobrem as operações principais.
Dicas para o seu Roteiro Atual
Mantenha a estrutura de pacotes: Tente replicar a estrutura de diretórios do Java (src/main/java/org/apache/pdfbox/...) dentro de lib/src/... no Dart. Isso facilita muito encontrar onde uma classe está e comparar o código durante o port.
Testes Unitários: Portar os testes unitários do Java para Dart (test package) é crucial. Para cada classe importante portada, porte seu teste correspondente.
Dependências Faltantes Imediatas:
Adicione archive ao seu pubspec.yaml urgentemente. Você precisa dele para o FlateFilter (zlib).
xml você já tem, será útil para portar o XmpBox (metadados XMP).
Comece pela Fase 1 (IO & COS). É impossível avançar sem ela estar sólida. Boa sorte, é um projeto grande e desafiador!

eu tenho os sub roteiros 
C:\MyDartProjects\pdfbox_dart\doc\roteiro_io.md
C:\MyDartProjects\pdfbox_dart\doc\roteiro_fontbox.md
# não é prioridade o xmpbox pois acho que para assinar PDF nõe precisa
C:\MyDartProjects\pdfbox_dart\doc\roteiro_xmpbox.md
o codigo java original esta em: C:\MyDartProjects\pdfbox_dart\pdfbox-java

eu embuti as seguintes dependências diretamente no projeto para eliminar a necessidade do pub get para elas, elas seram usadas na parte de validação e assinatura eletronica onde necessarior for:

asn1lib: Para manipulação de estruturas de dados ASN.1, fundamental para certificados e chaves.
basic_utils: Um conjunto de utilitários para várias operações, incluindo criptografia X.509 e manipulação de strings.
crypto_keys_plus: Uma camada de abstração para chaves criptográficas (simétricas e assimétricas).
dart_pkcs: Implementações para padrões de criptografia de chave pública (Public Key Cryptography Standards).
lzw: Implementação do algoritmo de compressão LZW.
lzw_compression: Outra implementação ou utilitário para compressão LZW.
pem: Para codificar e decodificar dados no formato PEM (usado para certificados e chaves).
rsa_pkcs: Utilitários específicos para parsing de chaves RSA nos formatos PKCS#1 e PKCS#8.
typed_data: Fornece buffers e listas eficientes para manipulação de dados binários.
universal_io: Uma biblioteca para I/O (entrada/saída) que funciona tanto em ambiente nativo quanto na web.
x509_plus: Utilitários para parsing e manipulação de certificados X.509.

e ja coloquei estas dependecias de projeto e ja rodei o pub get:

environment:
  sdk: ^3.6.0

dependencies:
  pointycastle: ^4.0.0
  meta: ^1.3.0
  collection: ^1.14.13
  archive: ^4.0.7
  crypto: ^3.0.7
  petitparser: '>=5.1.0 <8.0.0'
  image: ^4.5.4
  http: any #^1.5.0
  logging: any

ideal é ir portando implementando e testando (implementando ou portando testes e executando para ver se esta funcionando) e atualizando o roteiro
sempre executar  dart analyze para verificar se tem erros que impedem a compilação


Roteiro Detalhado para Portar o PDFBox para Dart
Este roteiro é dividido em fases. Cada fase representa um marco importante e constrói a base para a próxima. É crucial criar testes unitários para cada classe portada para garantir a fidelidade à implementação original.
Fase 0: Análise, Configuração e Ferramentas
Você já deu o primeiro passo criando o projeto. Agora, vamos formalizar a base.
Mapeamento de Dependências:
Criptografia: O PDFBox usa Bouncy Castle. Você já adicionou pointycastle, que é o equivalente no ecossistema Dart.
Compressão (Flate/zlib): O PDFBox usa java.util.zip. A biblioteca archive do Dart (package:archive/archive.dart) oferece implementações de ZLib/Deflate que serão essenciais.
Manipulação de Imagens: O Java tem o ImageIO e AWT. Você adicionou o package:image, que será a base para decodificar e manipular dados de imagem.
Análise de Fontes: Esta é uma das partes mais complexas. O PDFBox usa o FontBox. Não há um equivalente direto e completo em Dart. Você provavelmente precisará portar partes essenciais do FontBox ou criar um parser de fontes (TTF, Type 1) em Dart.
XML: Você já incluiu xml e xpath_selector, que substituirão as funcionalidades JAXP do Java.
Estrutura de Diretórios:
Para manter a organização, replique a estrutura de pacotes do Java dentro de lib/src/. Por exemplo:
lib/src/cos/ (para o pacote org.apache.pdfbox.cos)
lib/src/pdmodel/ (para o pacote org.apache.pdfbox.pdmodel)
lib/src/parser/ (para o pacote org.apache.pdfbox.pdfparser)
E assim por diante.
Estratégia de Testes:
Crie um diretório test/. Para cada classe que você portar (ex: cos/cos_array.dart), crie um teste correspondente (cos/cos_array_test.dart).
Use o PDF da própria especificação oficial como um dos seus principais arquivos de teste, além de outros PDFs que cubram diferentes funcionalidades.
Fase 1: O Coração do PDF - O Modelo de Objeto COS (Carousel Object System)
Esta é a base de tudo. Sem ela, nada mais funciona. O objetivo é criar representações fiéis dos tipos de dados primitivos de um PDF.
Pacote Java de Referência: org.apache.pdfbox.cos
Classes a Portar (sugestão de ordem):
COSBase.java -> cos_base.dart (Classe abstrata base).
COSNull.java, COSBoolean.java (Os mais simples).
COSNumber.java -> cos_number.dart (abstrata), COSInteger.java -> cos_integer.dart, COSFloat.java -> cos_float.dart.
COSName.java -> cos_name.dart (Essencial, representa nomes como /Type, /Page).
COSString.java -> cos_string.dart (Manipulação de strings literais e hexadecimais).
COSArray.java -> cos_array.dart (Representa vetores [...]).
COSDictionary.java -> cos_dictionary.dart (Representa dicionários <<...>>).
COSStream.java -> cos_stream.dart (Combina um COSDictionary com um fluxo de dados brutos).
COSObjectKey.java e COSObject.java -> cos_object_key.dart e cos_object.dart (Representam objetos indiretos, ex: 1 0 R).
COSDocument.java -> cos_document.dart (O contêiner de todos os objetos COS de um documento).
Meta da Fase: Ser capaz de criar e manipular uma estrutura de objetos PDF em memória. Os testes devem garantir que a criação, leitura e modificação de dicionários e vetores funcionem corretamente.
Fase 2: Decodificação de Streams - Filtros
Os COSStream contêm dados que quase sempre são comprimidos. Esta fase implementa os decodificadores.
Pacote Java de Referência: org.apache.pdfbox.filter
Classes a Portar:
Filter.java -> filter.dart (Interface ou classe abstrata base).
FlateFilter.java -> flate_filter.dart (Use o package:archive para a implementação do zlib).
ASCIIHexFilter.java -> ascii_hex_filter.dart.
ASCII85Filter.java -> ascii_85_filter.dart.
LZWFilter.java -> lzw_filter.dart.
CCITTFaxFilter.java -> ccitt_fax_filter.dart (Este é complexo, pode ser deixado para depois se não for uma prioridade inicial).
Meta da Fase: Conseguir ler um COSStream, aplicar os filtros corretos e obter os dados decodificados (descomprimidos).
Fase 3: O Parser - Lendo a Estrutura do Arquivo PDF
Esta fase é responsável por ler um arquivo .pdf, encontrar seus objetos e construir o modelo COSDocument.
Pacote Java de Referência: org.apache.pdfbox.pdfparser
Classes a Portar:
BaseParser.java -> base_parser.dart (Funções utilitárias de parsing).
COSParser.java -> cos_parser.dart (Lógica principal para parsear objetos COS).
XrefTrailerResolver.java, XrefParser.java, PDFXrefStreamParser.java (Classes cruciais para ler a tabela de referências cruzadas (xref) e encontrar os objetos no arquivo).
PDFParser.java -> pdf_parser.dart (Orquestra todo o processo de parsing do documento).
Meta da Fase: Ter uma função load(source) que possa ler um arquivo PDF, interpretar sua estrutura de xref e trailer, e carregar todos os objetos indiretos em um COSDocument. Este é um marco enorme.
Fase 4: O Modelo de Documento de Alto Nível (PDModel)
Com o COSDocument pronto, esta fase cria classes mais amigáveis e lógicas para interagir com o documento.
Pacote Java de Referência: org.apache.pdfbox.pdmodel
Classes a Portar:
PDDocument.java -> pd_document.dart (A classe principal para interagir com um PDF).
PDDocumentCatalog.java -> pd_document_catalog.dart (O objeto /Root).
PDPageTree.java -> pd_page_tree.dart e PDPage.java -> pd_page.dart.
PDResources.java -> pd_resources.dart (Gerencia recursos como fontes, imagens, etc.).
common/PDRectangle.java -> pd_rectangle.dart.
Meta da Fase: Ser capaz de carregar um documento e fazer operações como doc.getPage(0), page.getMediaBox(), e navegar pela estrutura lógica do PDF.
Fase 5: O Motor de Content Stream
Esta é a fase que interpreta os comandos de desenho de uma página. É fundamental para extração de texto e renderização.
Pacote Java de Referência: org.apache.pdfbox.contentstream e org.apache.pdfbox.contentstream.operator
Classes a Portar:
Operator.java -> operator.dart.
OperatorProcessor.java -> operator_processor.dart.
PDFStreamEngine.java -> pdf_stream_engine.dart (O cérebro do processo).
Comece portando os operadores mais importantes:
Texto: Tj (ShowText), TJ (ShowTextAdjusted), Tf (SetFontAndSize), Td/TD/Tm (posicionamento de texto), BT/ET.
Estado Gráfico: q (save), Q (restore), cm (concat matrix).
Paths: m (moveto), l (lineto), re (rectangle).
Desenho: S (stroke), f (fill), n (no-op path).
Objetos Externos: Do (desenha uma imagem ou formulário).
Meta da Fase: Ter um motor capaz de "visitar" o fluxo de conteúdo de uma página e executar ações para cada operador encontrado.
Fase 6: Fontes
Uma das partes mais desafiadoras. É impossível processar texto corretamente sem isso.
Pacote Java de Referência: org.apache.pdfbox.pdmodel.font
Dependência Externa: Você precisará de uma biblioteca para parsear arquivos de fonte (TTF, CFF). Se não houver uma pronta em Dart, será necessário portar as partes essenciais do Apache FontBox.
Classes a Portar:
PDFontDescriptor.java -> pd_font_descriptor.dart.
PDFont.java -> pd_font.dart (classe base).
PDSimpleFont.java -> pd_simple_font.dart.
PDType1Font.java -> pd_type1_font.dart.
PDTrueTypeFont.java -> pd_true_type_font.dart.
PDCIDFont.java -> pd_cid_font.dart (base para fontes compostas).
PDType0Font.java -> pd_type0_font.dart (essencial para Unicode).
Classes no pacote encoding.
Meta da Fase: Ser capaz de carregar fontes embutidas e as 14 fontes padrão, obter métricas de caracteres (largura, altura) e mapear códigos de caracteres para glifos.
Fase 7: Gráficos (Cores e Imagens)
Esta fase lida com os aspectos visuais além do texto.
Pacotes Java de Referência: org.apache.pdfbox.pdmodel.graphics.color, org.apache.pdfbox.pdmodel.graphics.image
Classes a Portar:
PDColorSpace.java e suas implementações (PDDeviceRGB, PDDeviceCMYK, PDDeviceGray, PDIndexed).
PDImageXObject.java -> pd_image_xobject.dart. Use o package:image para decodificar os formatos de imagem (JPEG, PNG, etc.).
PDFormXObject.java -> pd_form_xobject.dart.
Meta da Fase: Interpretar corretamente os espaços de cor e ser capaz de extrair os dados de imagens de um PDF.
Fase 8: Funcionalidades de Alto Nível
Após ter toda a base, você pode começar a implementar as funcionalidades que os usuários finais mais procuram.
Pacotes Java de Referência: org.apache.pdfbox.text, org.apache.pdfbox.multipdf
Funcionalidades a Portar:
Extração de Texto: Porte a classe PDFTextStripper.java. Esta será a primeira grande aplicação de todo o trabalho feito nas fases 5 e 6.
Merge de Documentos: Porte PDFMergerUtility.java.
Split de Documentos: Porte Splitter.java.
Criação de Páginas: Implemente APIs para criar novas páginas e desenhar conteúdo nelas.
Formulários (AcroForm): Pacote org.apache.pdfbox.pdmodel.interactive.form.
Anotações: Pacote org.apache.pdfbox.pdmodel.interactive.annotation.
Meta da Fase: Oferecer uma API rica e de alto nível para as operações mais comuns com arquivos PDF.
Dicas Gerais
Imutabilidade: Muitos objetos no PDFBox são wrappers imutáveis em torno de dicionários COS. Tente manter esse padrão.
Tratamento de Erros: O PDFBox é muito robusto contra PDFs malformados. Adote uma abordagem "leniente" (lenient) para o parsing sempre que possível, registrando avisos (warnings) em vez de lançar exceções, assim como a biblioteca original faz.
Performance: A manipulação de PDFs pode ser intensiva. Preste atenção ao uso de memória e CPU, especialmente no parsing de streams e fontes. Use Streams e processamento assíncrono do Dart onde fizer sentido.
Consulte a Especificação: Mantenha a especificação do PDF (ISO 32000) sempre à mão. O código do PDFBox faz muitas referências a seções específicas da especificação, e entendê-las é fundamental.
Este roteiro é um guia. Sinta-se à vontade para ajustar a ordem de algumas subtarefas, mas a sequência geral (COS -> Parser -> PDModel -> Content Stream) é a mais recomendada.

A seguir está o esqueleto do código em Dart para as classes principais, organizado pelas fases do roteiro. Eu traduzi os métodos e propriedades do Java para convenções idiomáticas do Dart (por exemplo, usando getters/setters em vez de getX/setX).
Lembre-se de criar testes para cada classe à medida que você implementa a lógica interna.
Fase 1: Modelo de Objeto COS (Core)
Diretório: lib/src/cos/
Este é o alicerce. Todos os outros componentes dependerão destas classes.
code
Dart
// --- lib/src/cos/cos_objectable.dart ---
import 'cos_base.dart';

/// Interface para objetos que podem ser convertidos para um objeto COS.
/// Em Dart, usamos uma classe abstrata para simular uma interface.
abstract class COSObjectable {
  COSBase getCOSObject();
}


// --- lib/src/cos/cos_base.dart ---
import 'cos_visitor.dart';

/// A classe base para todos os objetos no documento PDF.
abstract class COSBase implements COSObjectable {
  bool isDirect = false;

  @override
  COSBase getCOSObject() => this;

  /// Método do padrão de projeto Visitor.
  void accept(ICOSVisitor visitor);
}


// --- lib/src/cos/cos_name.dart ---
import 'cos_base.dart';
import 'cos_visitor.dart';

/// Representa um objeto de nome em PDF, como /Type ou /Page.
class COSName extends COSBase implements Comparable<COSName> {
  final String name;

  // Cache estático para reutilizar instâncias de nomes comuns.
  static final Map<String, COSName> _cache = {};

  // Construtor privado para controlar a criação.
  COSName._(this.name);

  // Factory para criar ou reutilizar instâncias de COSName.
  factory COSName(String name) {
    return _cache.putIfAbsent(name, () => COSName._(name));
  }
  
  // Nomes estáticos comuns
  static final COSName TYPE = COSName('Type');
  static final COSName PAGE = COSName('Page');
  // ... adicione outros nomes comuns aqui ...

  @override
  void accept(ICOSVisitor visitor) {
    // visitor.visitFromName(this);
  }
  
  @override
  int compareTo(COSName other) => name.compareTo(other.name);

  @override
  String toString() => '/$name';
}


// --- lib/src/cos/cos_dictionary.dart ---
import 'dart:collection';
import 'cos_array.dart';
import 'cos_base.dart';
import 'cos_name.dart';
import 'cos_object.dart';
import 'cos_visitor.dart';

/// Representa um dicionário PDF (<< ... >>).
class COSDictionary extends COSBase {
  final Map<COSName, COSBase> _items = LinkedHashMap<COSName, COSBase>();

  void setItem(COSName key, COSObjectable? value) {
    if (value == null) {
      removeItem(key);
    } else {
      _items[key] = value.getCOSObject();
    }
  }

  void removeItem(COSName key) {
    _items.remove(key);
  }

  COSBase? getItem(COSName key) {
    return _items[key];
  }
  
  /// Obtém um objeto, desreferenciando-o se for um COSObject.
  COSBase? getDictionaryObject(COSName key) {
    var obj = _items[key];
    if (obj is COSObject) {
      return obj.object;
    }
    return obj;
  }

  bool containsKey(COSName key) => _items.containsKey(key);
  
  COSArray? getCOSArray(COSName key) {
    var obj = getDictionaryObject(key);
    if (obj is COSArray) {
      return obj;
    }
    return null;
  }

  // ... outros métodos utilitários ...

  @override
  void accept(ICOSVisitor visitor) {
    // visitor.visitFromDictionary(this);
  }
}


// --- lib/src/cos/cos_array.dart ---
import 'cos_base.dart';
import 'cos_visitor.dart';

/// Representa um array PDF ([ ... ]).
class COSArray extends COSBase implements Iterable<COSBase> {
  final List<COSBase> _objects = [];

  void add(COSObjectable object) {
    _objects.add(object.getCOSObject());
  }

  COSBase get(int index) {
    return _objects[index];
  }
  
  // ... outros métodos utilitários ...

  @override
  Iterator<COSBase> get iterator => _objects.iterator;
  
  @override
  int get length => _objects.length;

  @override
  void accept(ICOSVisitor visitor) {
    // visitor.visitFromArray(this);
  }
}

// --- lib/src/cos/cos_stream.dart ---
import 'dart:typed_data';
import 'cos_dictionary.dart';
import 'cos_name.dart';

/// Um COSStream combina um dicionário com um fluxo de dados.
class COSStream extends COSDictionary {
  Uint8List? _bytes;

  // Implementar lógica para ler e decodificar os dados do stream
  // usando os filtros definidos no dicionário.

  List<COSName> get filters {
    // Lógica para ler o valor de /Filter
    return [];
  }
  
  Stream<List<int>> createInputStream() {
    // Lógica para decodificar e retornar um stream dos dados
    if (_bytes == null) return Stream.empty();
    return Stream.value(_bytes!);
  }

  // ...
}


// --- lib/src/cos/cos_object.dart ---
import 'cos_base.dart';
import 'cos_object_key.dart';
import 'cos_visitor.dart';

/// Representa um objeto indireto (ex: "1 0 R").
class COSObject extends COSBase {
  final COSObjectKey key;
  COSBase? _object;
  // Referência ao parser para carregamento tardio (lazy loading)
  // final PDFParser _parser; 

  COSObject(this.key, [this._object]);

  COSBase? get object {
    if (_object == null) {
      // Lógica para carregar o objeto do parser
      // _object = _parser.dereference(key);
    }
    return _object;
  }

  @override
  void accept(ICOSVisitor visitor) {
    // visitor.visitFromObject(this);
  }
}

// E assim por diante para as outras classes COS...```

---

### **Fase 2: Filtros (Decodificadores de Stream)**

**Diretório:** `lib/src/filter/`

```dart
// --- lib/src/filter/filter.dart ---
import 'dart:io';
import '../cos/cos_dictionary.dart';

/// Classe base abstrata para decodificar/codificar streams.
abstract class Filter {
  /// Decodifica um stream.
  void decode(InputStream input, OutputStream output, COSDictionary parameters, int index);

  /// Codifica um stream.
  void encode(InputStream input, OutputStream output, COSDictionary parameters);
}

// --- lib/src/filter/flate_filter.dart ---
import 'dart:io';
import 'package:archive/archive.dart';
import '../cos/cos_dictionary.dart';
import 'filter.dart';

/// Implementação para o filtro Flate (zlib/deflate).
class FlateFilter extends Filter {
  @override
  void decode(InputStream input, OutputStream output, COSDictionary parameters, int index) {
    // Lógica usando o package:archive (ZLibDecoder)
  }

  @override
  void encode(InputStream input, OutputStream output, COSDictionary parameters) {
    // Lógica usando o package:archive (ZLibEncoder)
  }
}
Fase 3: Parser (Leitor de Arquivo)
Diretório: lib/src/parser/
code
Dart
// --- lib/src/parser/random_access.dart ---
// Você precisará de uma classe abstrata para leitura de acesso aleatório,
// similar à RandomAccessRead do PDFBox. dart:io's RandomAccessFile é um bom ponto de partida.
abstract class RandomAccessRead {
  int read();
  void seek(int position);
  int get position;
  int get length;
  bool get isEOF;
  // ...
}

// --- lib/src/parser/base_parser.dart ---
import 'random_access.dart';

/// Contém a lógica de parsing de baixo nível comum.
abstract class BaseParser {
  final RandomAccessRead source;

  BaseParser(this.source);

  void skipSpaces() {
    // Implementar a lógica para pular espaços em branco e comentários
  }

  String readString() {
    // Implementar a lógica para ler um token
    return "";
  }
  
  // ... outros métodos utilitários de parsing ...
}

// --- lib/src/parser/pdf_parser.dart ---
import '../cos/cos_document.dart';
import '../pdmodel/pd_document.dart';
import 'cos_parser.dart';
import 'random_access.dart';

/// O parser principal que lê um arquivo PDF e o transforma em um PDDocument.
class PDFParser extends COSParser {
  PDFParser(RandomAccessRead source) : super(source);

  /// Realiza o parsing do documento inteiro.
  PDDocument parse() {
    // 1. Encontra o startxref
    // 2. Lê a tabela de xref e o trailer
    // 3. Constrói o COSDocument
    // 4. Retorna um PDDocument que encapsula o COSDocument
    
    // ... lógica de orquestração ...
    
    COSDocument cosDoc = COSDocument(); // Doc temporário
    return PDDocument(cosDoc);
  }
}
Fase 4: PDModel (Modelo de Documento de Alto Nível)
Diretório: lib/src/pdmodel/
code
Dart
// --- lib/src/pdmodel/pd_document.dart ---
import 'dart:io';
import '../cos/cos_document.dart';
import 'pd_document_catalog.dart';
import 'pd_page.dart';

/// A representação de alto nível de um documento PDF.
class PDDocument {
  final COSDocument document;

  PDDocument(this.document);
  
  PDDocumentCatalog get catalog => PDDocumentCatalog(this);
  
  int get numberOfPages {
    return catalog.pages.count;
  }
  
  PDPage getPage(int pageIndex) {
    return catalog.pages.get(pageIndex);
  }

  void save(String path) {
    // Lógica para escrever o COSDocument em um arquivo
  }
  
  void close() {
    document.close();
  }
}

// --- lib/src/pdmodel/pd_document_catalog.dart ---
import '../cos/cos_dictionary.dart';
import '../cos/cos_name.dart';
import 'pd_document.dart';
import 'pd_page_tree.dart';

/// Representa o dicionário /Root (Catálogo) do documento.
class PDDocumentCatalog {
  final COSDictionary _dictionary;
  
  PDDocumentCatalog(PDDocument doc) 
      : _dictionary = doc.document.trailer.getDictionaryObject(COSName('Root')) as COSDictionary;
  
  PDPageTree get pages {
    var dict = _dictionary.getDictionaryObject(COSName('Pages')) as COSDictionary;
  return PDPageTree(_document, dict);
  }
}

// --- lib/src/pdmodel/pd_page.dart ---
import '../cos/cos_dictionary.dart';
import '../cos/cos_stream.dart';
import 'common/pd_rectangle.dart';
import 'pd_resources.dart';

/// Representa uma única página no documento.
class PDPage {
  final COSDictionary _dictionary;

  PDPage(this._dictionary);

  PDRectangle get mediaBox {
    // Lógica para ler o /MediaBox
    return PDRectangle.fromCOSArray(_dictionary.getCOSArray(COSName('MediaBox'))!);
  }

  Stream<List<int>>? getContents() {
    // Lógica para obter o stream de conteúdo da página
    var content = _dictionary.getDictionaryObject(COSName('Contents'));
    if (content is COSStream) {
      return content.createInputStream();
    }
    return null; // ou um stream concatenado se for um array
  }
  
  PDResources? get resources {
    // ...
    return null;
  }
}
Fases Posteriores (Esqueletos Simplificados)
A partir daqui, as classes se tornam mais especializadas.
Fase 5: Content Stream (lib/src/contentstream/)
code
Dart
// --- lib/src/contentstream/pdf_stream_engine.dart ---
import '../cos/cos_name.dart';
import '../pdmodel/pd_page.dart';
import 'operator.dart';

/// Processa um fluxo de conteúdo PDF.
abstract class PDFStreamEngine {
  void processPage(PDPage page) {
    // Lógica para iterar sobre os operadores do stream de conteúdo da página
  }
  
  void processOperator(Operator op, List<dynamic> operands) {
    // Lógica para chamar o processador de operador correto
  }
}
Fase 6: Fontes (lib/src/pdmodel/font/)
code
Dart
// --- lib/src/pdmodel/font/pd_font.dart ---
import '../../cos/cos_dictionary.dart';

/// Classe base para todas as fontes PDF.
abstract class PDFont {
  final COSDictionary dictionary;

  PDFont(this.dictionary);

  String get name;
  
  double getWidth(int code);

  String toUnicode(int code);
  
  // ...
}
Fase 8: Utilitários (lib/src/multipdf/)
code
Dart
// --- lib/src/text/pdf_text_stripper.dart ---
import '../contentstream/pdf_stream_engine.dart';
import '../pdmodel/pd_document.dart';

/// Extrai texto de um documento PDF.
class PDFTextStripper extends PDFStreamEngine {
  
  /// Obtém o texto de um documento.
  String getText(PDDocument doc) {
    // Lógica para processar todas as páginas e extrair o texto
    return "";
  }

  // ... Sobrescrever métodos de PDFStreamEngine para capturar texto ...
}
Este esqueleto fornece uma estrutura sólida e a ordem lógica para começar a portar o PDFBox. Comece pela Fase 1 e certifique-se de que cada classe COS tenha um conjunto robusto de testes antes de prosseguir. Esta base é absolutamente essencial para o sucesso do restante do projeto. Boa sorte

Você montou uma base bem certinha pra um port grande desses 👍

Vou te devolver em 4 pontos: (1) o que já está no trilho, (2) o que está faltando criar agora, (3) sobre as dependências que você embutiu, (4) sobre o script de merge que aparece no VS Code.

1. O que já está no trilho

Documentação por fases: você já separou os roteiros por área (roteiro_io.md, roteiro_fontbox.md, o geral roteiro.md) e todos estão na mesma linha “IO → COS → parser → PDModel → conteúdo → fontes → assinatura”. Isso é exatamente a ordem que o próprio PDFBox segue, então tá ótimo. 

roteiro

 

roteiro_io

IO primeiro: o roteiro_io.md já descreve as interfaces RandomAccessRead/Write, buffer em memória, depois versão em arquivo e por fim o ScratchFile. Isso é exatamente o que o Java faz e é o que o PDFBox espera encontrar por baixo das outras camadas. Então começar por aí foi uma boa escolha. 

roteiro_io

 

roteiro_io

Você já pensou na parte de fontes (tem o roteiro_fontbox.md com AFM primeiro, depois CFF/TTF). Isso encaixa com a fase 4 do roteiro geral que você mesmo escreveu. É mais trabalho, mas está planejado. 

roteiro_fontbox

 

roteiro_fontbox

Você já listou as libs de crypto/compressão dentro do projeto, pra não depender de pub get no futuro — isso combina com o que você escreveu no roteiro.md sobre “eliminar a necessidade do pub get” e porque você quer assinar/validar PDF mais pra frente. 

roteiro

Então: visão geral e ordem de ataque estão boas.

2. O que está faltando criar agora

Pelo que aparece no screenshot, você já tem lib/src/io/ e pastas de “cauda longa” (xmpbox, fontbox). O que ainda não vi e que vira gargalo rápido:

lib/src/cos/ — o roteiro geral coloca COS como fase 1 junto de IO, porque o parser e o PDModel dependem disso. Falta criar as classes que você mesmo já esboçou no roteiro.md (COSBase, COSName, COSDictionary, COSArray, COSStream, COSObject, …). Sem isso você não consegue testar o parser assim que terminar o IO. 

roteiro

lib/src/parser/ (ou pdfparser/): assim que o IO estiver funcional e o COS existir, dá pra portar o “miolo” do BaseParser/COSParser que você descreveu no roteiro. Se deixar isso pra muito depois, você vai ter IO e COS prontos mas sem um jeito de carregar um PDF real. 

roteiro

tests/: em vários dos roteiros você mesmo falou “porte os testes JUnit” — mas ainda não vi a pasta de teste no screenshot. Se você criar agora test/io/... e for copiando os testes do PDFBox, você já congela a API e evita ter que mexer em 30 arquivos depois. 

roteiro_io

Separar o que é “core PDFBox” do que é “XMP/assinado”: você comentou no roteiro que XMP não é prioridade pra assinar PDF — está certo, assinatura no PDFBox vive em pdmodel.interactive.digitalsignature e não exige XMP. Então pode mesmo deixar o que está no roteiro_xmpbox.md pra depois. 

roteiro

Resumo do próximo passo

Fecha o IO conforme o roteiro_io.md (inclusive ScratchFile). 

roteiro_io

Cria o lib/src/cos/ exatamente como está no trecho do roteiro — copia esse esqueleto e transforma em arquivo de verdade. 

roteiro

Só depois disso vai pro parser.

XMP pode esperar não é prioridade.

Se quiser, no próximo passo me mostra o conteúdo de lib/src/io/ que você já escreveu (não só o plano) que eu te digo se a API está batendo com o que o parser vai precisar.
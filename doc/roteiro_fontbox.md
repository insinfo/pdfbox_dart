## Plano do porte FontBox

O objetivo é portar `org.apache.fontbox` para Dart seguindo a mesma abordagem incremental usada no módulo IO: implementar blocos coesos, portar testes de referência e manter documentação viva.

codigo original em C:\MyDartProjects\pdfbox_dart\pdfbox-java\fontbox

### Estrutura de trabalho
- Priorizar utilitários independentes (`util`, `encoding`, `cmap`) para destravar demais pacotes.
- Em seguida portar as estruturas textuais (`afm`) e os modelos de fonte base (`FontBoxFont`, `EncodedFont`).
- Finalizar com os formatos binários (`cff`, `ttf`, `type1`, `pfb`) e respectivos testes.

### Backlog inicial
1. Portar `BoundingBox` e helpers de `util`. **(concluído: `BoundingBox`, autodetect finders, `FontFileFinder` + testes)**
2. Criar camada de leitura binária (`fontbox/io` em Dart) para substituir `RandomAccessRead` + `DataInput` usados pelo Java. **(concluído: `TtfDataStream`, `RandomAccessRead*`, `TtcDataStream` + testes)**
3. Trazer modelos AFM básicos (`FontMetrics`, `CharMetric`, `Ligature`, etc.) e parser textual. **(concluído: modelos AFM e `AFMParser` com testes dedicados)**
4. Garantir suporte a encodings e cmaps compartilhados (`CMap`, `CMapParser`, `CMapLookup`). **(em andamento: `CMap` + `CMapParser` portados com testes; `CMapLookup` e `CmapSubtable` expostos em Dart, faltam leitores binários e integrações)**
5. Portar formatos binários começando por CFF (depende de 1–4) e, na sequência, TTF.

### Estado atual (2025-11-05)
- `lib/src/fontbox/util/bounding_box.dart` implementado com cobertura em `test/fontbox/util/bounding_box_test.dart`.
- `fontbox/util/autodetect` portado (`FontDirFinder`, variantes nativas e `FontFileFinder`) com testes em `test/fontbox/util/autodetect/font_file_finder_test.dart`.
- Camada binária inicial pronta em `fontbox/io` (`TtfDataStream`, `RandomAccessReadDataStream`, `RandomAccessReadUnbufferedDataStream`, `TtcDataStream`) com testes em `test/fontbox/io/ttf_data_stream_test.dart`.
- Encodings básicos portados (`StandardEncoding`, `MacRomanEncoding`, `BuiltInEncoding`) com testes em `test/fontbox/encoding/encoding_test.dart`.
- Modelos AFM disponíveis em `lib/src/fontbox/afm` (FontMetrics, CharMetric, Ligature, Composite, TrackKern, KernPair) e parser `AFMParser` com cobertura em `test/fontbox/afm`.
- Bloco `fontbox/cmap` iniciado com `CMap`, `CodespaceRange`, `CidRange` e `CMapParser` validados em `test/fontbox/cmap/cmap_parser_test.dart`.
- Interface `CMapLookup` portada para `lib/src/fontbox/ttf/cmap_lookup.dart`, preparando a etapa das tabelas TrueType.
- Estruturas iniciais de `fontbox/ttf` iniciadas com `CmapSubtable` e testes em `test/fontbox/ttf/cmap_subtable_test.dart`.

### Próximas ações
- Integrar e exportar os modelos/parsers AFM quando houver consumidor no pacote principal.
- Completar o pacote `org.apache.fontbox.cmap` implementando componentes consumidores (`CMapLookup` → lookup real) e amarrando a superfície pública (`pdfbox_dart.dart`).
- Levantar dependências de `FontBoxFont`/`EncodedFont` e montar plano para conversão após concluir `cmap`.
- Detalhar sequência de porte das tabelas TTF que dependem da camada `fontbox/io` (glyf, head, loca, etc.).
- Evoluir o leitor de cmap TrueType (formatos 4/12 prioritários) utilizando `CmapSubtable`.
## Plano do porte FontBox

O objetivo é portar `org.apache.fontbox` para Dart seguindo a mesma abordagem incremental usada no módulo IO: implementar blocos coesos, portar testes de referência e manter documentação viva.
codigo dart em: C:\MyDartProjects\pdfbox_dart\lib
codigo original em C:\MyDartProjects\pdfbox_dart\pdfbox-java\fontbox
testes originais em C:\MyDartProjects\pdfbox_dart\pdfbox-java\fontbox\src\test

### Estrutura de trabalho
- Status TTF: 67/81 arquivos Java já portados (faltam 14 para cobrir todo o pacote `org.apache.fontbox.ttf`).
- Priorizar utilitários independentes (`util`, `encoding`, `cmap`) para destravar demais pacotes.
- Em seguida portar as estruturas textuais (`afm`) e os modelos de fonte base (`FontBoxFont`, `EncodedFont`).
- Finalizar com os formatos binários (`cff`, `ttf`, `type1`, `pfb`) e respectivos testes.

### Backlog inicial
1. Portar `BoundingBox` e helpers de `util`. **(concluído: `BoundingBox`, autodetect finders, `FontFileFinder` + testes)**
2. Criar camada de leitura binária (`fontbox/io` em Dart) para substituir `RandomAccessRead` + `DataInput` usados pelo Java. **(concluído: `TtfDataStream`, `RandomAccessRead*`, `TtcDataStream` + testes)**
3. Trazer modelos AFM básicos (`FontMetrics`, `CharMetric`, `Ligature`, etc.) e parser textual. **(concluído: modelos AFM e `AFMParser` com testes dedicados)**
4. Garantir suporte a encodings e cmaps compartilhados (`CMap`, `CMapParser`, `CMapLookup`). **(em andamento: `CMap` + `CMapParser` portados com testes; `CMapLookup` e `CmapSubtable` cobrem formatos 0/2/4/6/8/10/12/13/14 com testes dedicados; integrações com consumidores ainda em progresso)**
5. Portar formatos binários começando por CFF (depende de 1–4) e, na sequência, TTF.

### Estado atual (2025-11-07)
- `lib/src/fontbox/util/bounding_box.dart` implementado com cobertura em `test/fontbox/util/bounding_box_test.dart`.
- `fontbox/util/autodetect` portado (`FontDirFinder`, variantes nativas e `FontFileFinder`) com testes em `test/fontbox/util/autodetect/font_file_finder_test.dart`.
- Camada binária inicial pronta em `fontbox/io` (`TtfDataStream`, `RandomAccessReadDataStream`, `RandomAccessReadUnbufferedDataStream`, `TtcDataStream`) com testes em `test/fontbox/io/ttf_data_stream_test.dart`.
- Encodings básicos portados (`StandardEncoding`, `MacRomanEncoding`, `BuiltInEncoding`) com testes em `test/fontbox/encoding/encoding_test.dart`.
- Modelos AFM disponíveis em `lib/src/fontbox/afm` (FontMetrics, CharMetric, Ligature, Composite, TrackKern, KernPair) e parser `AFMParser` com cobertura em `test/fontbox/afm`.
- Bloco `fontbox/cmap` iniciado com `CMap`, `CodespaceRange`, `CidRange` e `CMapParser` validados em `test/fontbox/cmap/cmap_parser_test.dart`.
- Interface `CMapLookup` portada para `lib/src/fontbox/ttf/cmap_lookup.dart`, preparando a etapa das tabelas TrueType.
- Estruturas iniciais de `fontbox/ttf` avançadas com `CmapSubtable` interpretando formatos 0/2/4/6/8/10/12/13/14, integrando UVS (formato 14) diretamente em `TrueTypeFont.getUnicodeCmapLookup` e em `SubstitutingCmapLookup.mapCodePoints`, com cobertura em `test/fontbox/ttf/` e validação via `scripts/inspect_cmap.dart` contra fontes reais.
- Infraestrutura TTF/GSUB inicial ativada com `TTFTable`, `FontHeaders`, `DigitalSignatureTable`, `OtlTable`, utilitário `Wgl4Names` e os modelos `Language`, `GsubData`, `MapBackedGsubData`, `MapBackedScriptFeature`/`ScriptFeature`, acompanhados dos testes sob `test/fontbox/ttf/` e `test/fontbox/ttf/model`.
- Pacote `fontbox/ttf/table/common` iniciado com `RangeRecord`, `CoverageTable*`, `Feature*`, `LangSysTable`, `ScriptTable`, `Lookup*` e bateria dedicada em `test/fontbox/ttf/table/common/common_tables_test.dart` garantindo comportamento e imutabilidade base.
- Renderização de contornos habilitada: `GlyphRenderer`, `GlyphPath` e integração via `GlyphData.getPath()` com casos em `test/fontbox/ttf/glyf/glyf_descript_test.dart` exercitando contornos simples e compostos.
- Tabelas verticais portadas (`VerticalHeaderTable`, `VerticalMetricsTable`, `VerticalOriginTable`) com cobertura sintética em `test/fontbox/ttf/vertical_tables_test.dart` e integração em `TrueTypeFont` para expor métricas verticais.
- Script auxiliar `scripts/inspect_cmap.dart` criado para validar parsing de cmaps contra fontes reais e coletar estatísticas rápidas dos subtables.
- Script ajustado para detectar automaticamente fontes OTF/CFF (via `OtfParser`) e validar UVS em Segoe UI Emoji e Noto Sans JP.
- Script adicional `scripts/validate_uvs.dart` percorre diretórios de fontes, agrega estatísticas de UVS e valida que os mapeamentos padrão e alternativos estão consistentes com o cmap base.
- `scripts/generate_unicode_scripts.dart` passou a ordenar/mesclar os intervalos de `Scripts.txt`, alimentando `unicode_scripts_data.dart` em ordem crescente; `OpenTypeScript` agora consulta o mapeamento completo via busca binária e está coberto pelos testes em `test/fontbox/ttf/open_type_script_test.dart`.
- `OpenTypeFont` expandido com suporte a `hasLayoutTables`, exposição do `CffTable` e guarda de `glyf` alinhada ao comportamento do Java, com testes em `test/fontbox/ttf/open_type_font_test.dart`.
- `KerningSubtable` passou a cobrir o formato 2 baseado em classes, com casos em `test/fontbox/ttf/kerning_table_test.dart` garantindo leitura e consulta dos ajustes.
- Correção aplicada ao parser de `cmap` formato 14, eliminando o desalinhamento do cabeçalho e permitindo validar UVS reais; `seguiemj.ttf` (Segoe UI Emoji) agora é analisada com sucesso via `scripts/inspect_cmap.dart`.
- Pacote `fontbox/cff` iniciado com infraestrutura compartilhada (`DataInput`, leitores para `Uint8List` e `RandomAccessRead`, mapeamento de operadores, `CharStringCommand`) e avançou com o suporte a nomes/encodings padrão (`CFFStandardString`, `CFFStandardEncoding`) acompanhados de testes em `test/fontbox/cff/cff_standard_encoding_test.dart`.

### Próximas ações
- Validar as UVS decodificadas em fluxo real (ex.: PDFs com Variation Selectors, fontes Segoe UI Emoji/Noto Color Emoji), assegurando paridade com o Java e documentando eventuais gaps; `scripts/validate_uvs.dart` já cobre estatísticas diretas em diretórios de fontes, restando exercitar PDFs e fontes adicionais (ex.: Noto Color Emoji).
- Portar as tabelas TTF restantes em sequência (ex.: `KerningTable`, `PostScriptTable`, `OS2WindowsMetricsTable`, `AdvancedTypographicTable`s), mantendo o contador atualizado.
- Integrar consumidores das métricas verticais (GSUB/Glyf e camadas superiores) validando regressões com casos reais.
- Completar o pacote `org.apache.fontbox.cmap`, conectando `CMapLookup` às estruturas reais e expondo o fluxo no pacote principal.
- Mapear dependências de `FontBoxFont`/`EncodedFont` para preparar a etapa de fontes compostas após finalizar as tabelas essenciais.

### Pendencias mapeadas (2025-11-07)
- `lib/src/fontbox/ttf/cff_table.dart`: apenas armazena os bytes crus do CFF; falta portar o parser completo de `org.apache.fontbox.cff`.
- `lib/src/fontbox/ttf/otl_table.dart`: JSTF ainda é um stub; precisa da leitura completa em linha com `org.apache.fontbox.ttf.JSTFTable`.
- `lib/src/fontbox/ttf/open_type_font.dart`: já identifica PostScript, expõe `CffTable` e detecta tabelas de layout, porém ainda falta a API completa (ex.: renderização via CFF, integração com `PDType0Font`).
- `lib/src/fontbox/ttf/ttf_parser.dart`: rejeita fontes TrueType com outlines CFF quando processadas pelo parser base; é necessário alinhar com a lógica Java que usa `OtfParser`/`CFFParser`.
- Fluxo de validação de UVS: `seguiemj.ttf` validada após correção do formato 14; próxima etapa é exercitar PDFs reais e outras fontes (ex.: Noto Color Emoji) para confirmar substituições contextuais.
- `lib/src/fontbox/ttf/kerning_subtable.dart`: formatos 0 e 2 implementados; formato 1 (state-based) permanece sem suporte.
- `lib/src/fontbox/ttf/naming_table.dart`: formatos 0 e 1 cobertos; falta alinhar com o suporte Java ao formato 3 (offsets de 32 bits / lang tags avançados).
- `lib/src/fontbox/ttf/glyph_substitution_table.dart`: parser de GSUB cobre apenas lookup types 1-4; demais tipos (5-10) e FeatureVariations ainda faltam.
- `lib/src/fontbox/ttf/gsub/glyph_substitution_data_extractor.dart`: segue as mesmas limitações do parser (tipos 1-4), ignorando substituições complexas.
- `lib/src/fontbox/ttf/open_type_script.dart` e `lib/src/fontbox/ttf/model/language.dart`: o arquivo gerado cobre todos os intervalos de `Scripts.txt`, porém o dicionário `_scriptToTags` e a enumeração de idiomas ainda são parciais e precisam incorporar os demais scripts/tags definidos pelo Java.

Panorama Atual

O roteiro continua válido: faltam ~14 arquivos Java do pacote org.apache.fontbox.ttf e nenhum dos pacotes cff, type1, pfb, cid foi portado para Dart. Na árvore fontbox só existem afm, cmap, encoding, io, ttf e util, então boa parte das APIs clássicas de FontBox ainda está ausente.
Dentro de TTF, alguns blocos estão apenas esboçados: CffTable só guarda bytes crus; OtlTable e OpenTypeFont expõem um subconjunto mínimo; TtfParser rejeita automaticamente fontes TrueType com outlines CFF quando não é chamado via OtfParser; KerningSubtable cobre apenas o formato 0; NamingTable não lê o formato 3; GSUB suporta apenas lookups 1‑4 e a extração de dados (GlyphSubstitutionDataExtractor) herda essas limitações; OpenTypeScript/language.dart ainda têm mapementos reduzidos.
O roteiro também aponta tarefas pendentes de validação prática: rodar inspect_cmap.dart (ou um fluxo equivalente) em fontes reais/PDFs com Variation Selectors para comprovar a integração UVS recentemente concluída. Isso ainda não foi feito.
O que falta para concluir o porte do FontBox

Implementar o parser completo de CFF (org.apache.fontbox.cff.*) e os formatos Type 1/PFB; sem isso, fontes PostScript continuam inacessíveis.
Portar os componentes de fontes compostas (CIDFont, FontBoxFont, EncodedFont, GlyphList, etc.) e os utilitários que o PDFBox usa para fontes Type 0, CID, multibyte e conversões de codificação.
Completar o pacote TTF: suportar os formatos restantes de KerningSubtable, alinhar NamingTable com o formato 3, expandir GSUB (lookups 5‑10, FeatureVariations, JSTF) e carregar a tabela OpenTypeScript com o mapeamento oficial.
Revisitar TrueTypeFont/TtfParser/OtfParser para aceitar o mesmo espectro de fontes que o Java (inclusive TTC, OTF com CFF/CFF2, fontes embutidas em PDFs, etc.) e adicionar o ciclo completo de testes com arquivos reais.
Portar/blindar os módulos auxiliares de FontBox que o PDFBox consome diretamente (metadados, UnicodeMapping, encodings adicionais, caches).
Prontidão para iniciar o porte do PDFBox

O núcleo do FontBox ainda não corresponde ao que o PDFBox espera: boa parte das classes usadas por PDType0Font, PDCIDFontType0, PDType1Font, PDTrueTypeFont e pelos renderizadores está ausente ou incompleta. Sem CFF/Type1/PFB, sem GSUB completo e sem os modelos de fontes compostas, qualquer tentativa de portar o PDFBox ficaria limitada a PDFs muito simples com fontes TrueType pouco sofisticadas.
Também faltam APIs fontbox importantes que o PDFBox chama diretamente (por exemplo, FontBoxFont, CIDFontType2, Type1Parser, AFMParser avançado para métricas, cache de fontes do sistema, etc.). Hoje não há substitutos prontos em Dart.
Em resumo: o que já foi portado (AFM, cmap, blocos básicos de TTF, logging, IO) é uma base sólida, mas insuficiente para iniciar o PDFBox sem entrar em uma nova rodada de stubs e regressões. Ainda é necessário completar os itens críticos do roteiro antes de migrar camadas do PDFBox que dependem fortemente de FontBox.
Próximos Passos Sugeridos

Validar imediatamente os novos helpers de UVS com dart run scripts/inspect_cmap.dart em fontes reais (Segoe UI Emoji, Noto Color Emoji) e, se possível, em PDFs que exercitem Variation Selectors; documentar os resultados no roteiro.
Priorizar o porte do parser CFF + Type1/PFB (ou pelo menos disponibilizar decodificação parcial) para desbloquear fontes PostScript.
Ampliar o suporte GSUB/JSTF e os mapeamentos de scripts, em paralelo à conclusão da leitura das tabelas TTF pendentes.
Só depois de completar esses blocos iniciar o PDFBox, garantindo que a camada de fontes usada por PD*Font já esteja pronta ou ao menos bem limitada e documentada.
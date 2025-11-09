## Porte FontBox para Dart  Pendências Restantes

### Objetivo
Garantir paridade com `org.apache.fontbox` (Java) para habilitar o porte do PDFBox sem stubs adicionais.

### Ações críticas
- Finalizar o pipeline PostScript: parser CFF, Type 1 e PFB já existem em Dart e agora incluem `Type1Parser`, `Type1Font` e contratos (`FontBoxFont`, `EncodedFont`) portados; `CFFFont`/`CFFType1Font`/`CFFCIDFont` já expõem os contratos compartilhados, e a próxima etapa é alinhar caches auxiliares e consumidores Type 0/CID.
- Portar os modelos de fontes compostas (CIDFont, FontBoxFont, EncodedFont, GlyphList etc.) usados em fontes Type 0/CID.
- Alinhar `TtfParser`, `OtfParser`, `OpenTypeFont` e `OtlTable` ao Java, cobrindo TTC/OTF com glyf, CFF, CFF2 e JSTF.
- Completar GSUB/JSTF: suportar lookups 510, FeatureVariations e atualizar o extrator de substituição.
- Preencher `_scriptToTags` e `model/language.dart` com todos os scripts/tags do Java e criar testes específicos para os novos scripts.
- Finalizar `org.apache.fontbox.cmap` em Dart e validar `CMapLookup` com consumidores reais.
- Integrar métricas verticais, GSUB/GPOS e derivados aos pontos de consumo espelhando a API Java.
- Portar módulos auxiliares requisitados pelo PDFBox (UnicodeMapping, caches de fontes do sistema, metadados adicionais, etc.).

### Validação e cobertura
- Exercitar `scripts/inspect_cmap.dart` e `scripts/validate_uvs.dart` em fontes/PDFs reais (Variation Selectors, CFF/CFF2, TTC) e registrar resultados.
- Adicionar testes de regressão para CFF/Type1, GSUB avançado, kerning state-based e os novos scripts/tags.
- A suíte Type 1 agora inclui casos de PFB com `lenIV > 0`, fallback explícito para `.notdef` e carregamento de sub-rotinas (`/Subrs`), validando decriptação, cache e suporte a `callsubr`.
- A suíte CID exercita `CFFCIDFont` com caches compartilhados e fallback para `.notdef`, garantindo que os caminhos e widths reutilizem charstrings conforme a implementação Java.
- A suíte CFF cobre `CFFType1Font` e `CFFCIDFont` contra o contrato `FontBoxFont`, incluindo validação de bounding box, matrix e cache de charstrings.
- A suíte CFF cobre `CFFType1Font` contra o contrato `FontBoxFont`, incluindo validação de bounding box, matrix e cache de charstrings `Type2`.
- Garantir que a suíte Dart reproduza a matriz de fontes usada pelos testes Java (inclusive arquivos de referência).

### Critério de saída
Considerar o porte concluído quando todos os itens acima estiverem implementados e cobertos por testes equivalentes aos do Java, permitindo iniciar o porte do PDFBox sem extensões temporárias no FontBox.

- Consolidar o pipeline Type 1 consumindo o `PfbParser` recém-portado, alinhando caches e leitura de subrotinas externas com os consumidores compostos.
- Expandir `_scriptToTags`/`language.dart` e adicionar testes direcionados para novos scripts.
- Validar UVS e GSUB atuais em fontes reais e documentar resultados no repositório.

### Panorama atual
O núcleo CFF/Type 1 está disponível: parser CFF, charsets padrão/expert, charstring path, `Type1CharString`, `Type2CharString`/parser e o reader para `CFFType1Font`/`CFFCIDFont` já foram portados. `Type1Parser`, `Type1Font`, `FontBoxFont` e `EncodedFont` agora também estão implementados com testes equivalentes. O `CffTable` instância fontes PostScript com fallback seguro quando encontra CFF corrompido. Ainda faltam ajustar caches auxiliares e validar fluxos compostos para atingir paridade completa com o Java.

As classes CFF agora implementam diretamente `FontBoxFont`/`EncodedFont`, permitindo compartilhar consumidores Type 1/Type 0 e garantindo paridade com o contrato Java. Novos testes cobrem o uso do cache de charstrings e métricas expostas por `CFFType1Font` e `CFFCIDFont`.

O pipeline de nomes e codificações recebeu o gerador de `glyph_list_data.dart`, além das portas de `WinAnsiEncoding`, `MacExpertEncoding`, `SymbolEncoding`, `ZapfDingbatsEncoding` e da nova `GlyphList`, preparando o suporte às listas Adobe Glyph List/Zapf e aos consumidores Type 1. A camada PDFBox já expõe um wrapper `pdmodel/font/encoding/GlyphList` delegando para essa infraestrutura.

No pacote TTF seguimos com lacunas: `OtlTable` permanece stub, `OpenTypeFont` ainda é parcialmente portado, e `_scriptToTags`/`language.dart` continuam reduzidos. A infraestrutura GSUB/JSTF avançada e validação UVS prática seguem pendentes.

Persistem pendências de validação prática: executar `inspect_cmap.dart`/`validate_uvs.dart` em amostras reais, criar fixtures que exercitem Type 1/CID carregados via `CffTable` e ampliar a suíte com casos GSUB/JSTF complexos e kerning state-based.

### Próximos passos sugeridos
- Validar imediatamente os novos helpers de UVS com `dart run scripts/inspect_cmap.dart` em fontes reais (Segoe UI Emoji, Noto Color Emoji) e, se possível, em PDFs que exercitem Variation Selectors; documentar os resultados.
- Validar e integrar o pipeline Type 1 recém-portado com consumidores Type 0/CID e caches compartilhados.
- Ampliar o suporte GSUB/JSTF e os mapeamentos de scripts em paralelo à conclusão das tabelas TTF pendentes, antes de iniciar o porte das camadas do PDFBox que dependem dessas APIs.
- Exercitar as novas classes de charstring (`Type2CharString`, `CFFCIDFont`) em fontes reais, documentando métricas e eventuais gaps na integração com consumidores do PDFBox.

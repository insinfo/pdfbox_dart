## Porte FontBox para Dart – Status Atual

### Objetivo
Garantir paridade com `org.apache.fontbox` (Java) para permitir o porte do PDFBox sem dependências temporárias.

### Concluído recentemente
- `TTFSubsetter` foi portado e coberto por testes de regressão em Dart, garantindo closure de glifos, reescrita das tabelas essenciais (`cmap`, `glyf`, `loca`, `hmtx`) e suporte a glyph invisíveis. Os testes agora consomem as fontes da pasta local `resources/ttf`, sem depender da árvore Java.
- `TtfParser` aplica leitura antecipada da tabela `maxp`, reproduzindo o fluxo do FontBox Java e eliminando divergências ao carregar `loca/glyf` em fontes reais.
- O pacote de CMaps predefinidos continua embedado e validado via testes (`Identity-H`, `usecmap`), com geração automatizada pelos scripts em `scripts/`.
- O pipeline Type 1/CFF, Type 0/CID, encodings e glyph lists mantém paridade funcional com o Java, cobrindo charstrings, caches, métricas verticais e mapas Adobe UCS.
- Infraestrutura PDFBox (mapeamentos CID, encodings, helpers Type 0) permanece estabilizada com suites unitárias equivalentes.
- Execução completa de GPOS via `GlyphPositioningExecutor`, incluindo pair adjustment, cursive e mark attachment com rastreamento por lookup.
- Controlador JSTF (`JstfPriorityController`) integrado aos pipelines GSUB/GPOS, habilitando filtros de lookup por modo (shrink/extend) e scripts.
- Catálogo de scripts/idiomas expandido na camada `model/language.dart`, permitindo resolução cruzada com JSTF.
- Testes abrangentes para GSUB/GPOS/JSTF (`gpos_table_test.dart`, `glyph_substitution_table_test.dart`, `true_type_font_test.dart`) e harness `scripts/validate_layout.dart` criado para rodar inspeções (`inspect_cmap.dart`, `validate_uvs.dart`).

### Trabalho em andamento
- **FeatureVariations condicionais:** aplicar resolução dependente de eixos para GSUB/GPOS, reutilizando o estado do executor e cobrindo cenários de var fonts.
- **Cobertura JSTF/BASE ampliada:** validar prioridades langSys alternativos, prioridades extend/shrink simultâneas e conexão com BASE para ancoragem.
- **Validação prática:** rodar `inspect_cmap.dart`, `validate_uvs.dart` e PDFs/fontes reais para cobrir Variation Selectors, TTC, CFF/CFF2 e registrar achados.
- **CFF2 e variações:** estender parser/workers para fontes variáveis após estabilizar GPOS/JSTF.
- **Infraestrutura auxiliar PDFBox:** finalizar módulos remanescentes (UnicodeMapping, caches de fontes do sistema, metadados) necessários para consumir as fontes dentro do PDModel.

### Próximas entregas
- Completar aplicação de FeatureVariations condicionais e expor o estado de eixos para GSUB/GPOS.
- Ampliar testes JSTF/BASE cobrindo langSys alternativos, shrink/extend simultâneos e interação com mark attachment.
- Criar suites adicionais que cubram mark attachment, kerning state-based, scripts recém-adicionados e regressões do TTFSubsetter.
- Rodar a matriz de validação com fontes/PDFs reais e documentar resultados (UVS, CJK, variações, Type 1/CID complexos).
- Preparar suporte a CFF2 e fontes variáveis após a estabilização das etapas acima.

### Critério de saída
O porte será considerado encerrado quando:
- GSUB/GPOS/JSTF estiverem funcionais com FeatureVariations condicionais e cobertura por testes dirigidos a scripts/languages.
- `TTFSubsetter` e pipelines Type 0/Type 1/CFF/CID forem exercitados por suites de regressão equivalentes às do Java, incluindo fixtures reais.
- Scripts de validação (`inspect_cmap.dart`, `validate_uvs.dart`) rodarem limpos sobre a matriz de fontes adotada no projeto.
- Os módulos auxiliares requeridos pelo PDFBox estiverem disponíveis e validados, permitindo o porte do PDModel sem stubs.

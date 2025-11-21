# Roteiro de Portabilidade PDFBox para Dart (Status: Novembro 2025)

### referencias de jbig2
https://github.com/agl/jbig2enc
https://github.com/zdenop/jbig2enc-samples
https://github.com/ocrmypdf/OCRmyPDF/issues/748
https://github.com/anotatta/jbig2enc

Este documento descreve o estado atual do projeto e o que ainda falta para concluir o porte da biblioteca Apache PDFBox para Dart.

não pode depender do diretorio pdfbox-java pois ele sera removido depois que o port tiver sido concluido pdfbox-java/pdfbox/src/test/resources

## ✅ O Que Já Está Feito (Status Atual)

O núcleo da biblioteca está funcional e permite ler, criar, modificar, salvar, criptografar, assinar e mesclar documentos PDF.

### 1. Fundação (Core)
- **IO**: `RandomAccessRead`, `RandomAccessWrite`, `ScratchFile` (memória e disco) implementados.
- **COS (Carousel Object System)**: Todos os tipos básicos (`COSBase`, `COSDictionary`, `COSArray`, `COSStream`, `COSName`, etc.) estão portados e testados.
- **Parser**: `PDFParser`, `COSParser`, `XrefTrailerResolver` funcionais. Suporta leitura de arquivos, streams e brute-force parsing.
- **Writer**: `COSWriter` implementado, suportando salvamento incremental e criptografia.

### 2. PDModel (Modelo de Documento)
- **Estrutura**: `PDDocument`, `PDPage`, `PDPageTree`, `PDResources` implementados.
- **Fontes**: Suporte robusto para Type1, TrueType (com subsetting), CIDFonts (Type0/Type2) e carregamento de arquivos de fonte (`.ttf`, `.otf`, `.pfb`).
- **Gráficos**: `PDPageContentStream` implementado para desenhar textos, formas e imagens.
- **Imagens**: `PDImageXObject` (JPEG, PNG via `package:image`), `PDFormXObject`.
- **Interativo**:
    - **Anotações**: `PDAnnotation` e subclasses básicas.
    - **Formulários (AcroForm)**: `PDAcroForm`, campos de texto, botões, escolhas. Geração de aparência básica.
    - **Assinatura Digital**: `PDSignature`, `SignatureOptions`, `PDSeedValue`. Estrutura pronta para assinar.
- **Criptografia**: Suporte a RC4, AES-128, AES-256, permissões e handlers de segurança padrão.

### 3. Utilitários
- **Multipdf**:
    - `PDFMergerUtility`: **Concluído**. Suporta mesclagem de documentos, incluindo AcroForms, Árvore de Estrutura (Tagging/Acessibilidade), Page Labels e Outlines.
    - `Splitter`, `Overlay`, `LayerUtility`: Estruturas presentes.

### 4. FontBox
- Portado em `lib/src/fontbox`. Suporta parsing de TTF, OTF, CFF, Type1 e tabelas CMap.

---

## 🚧 O Que Falta (Roadmap para Conclusão)

Para considerar o porte "completo" em relação ao PDFBox Java, as seguintes áreas principais precisam ser implementadas:

### 1. Extração de Texto (`org.apache.pdfbox.text`) - **Prioridade Alta**
Esta é a maior lacuna funcional no momento. Sem isso, não é possível extrair texto legível de um PDF.
- **Falta**:
    - `PDFTextStripper`: Classe principal para extrair texto.
    - `TextPosition`: Representa a posição e propriedades de cada caractere.
    - Lógica de processamento de layout de texto (bidi, ordenação, agrupamento).

### 2. Renderização (`org.apache.pdfbox.rendering`) - **Prioridade baixa**
Necessário para converter páginas PDF em imagens (bitmaps) para visualização.
- **Falta**:
    - `PDFRenderer`: Classe principal que orquestra a renderização.
    - `PageDrawer`: Implementação de `PDFGraphicsStreamEngine` que desenha em um canvas (no Java usa AWT, no Dart precisará usar `package:image`  para este pacote puro Dart, `package:image` é o caminho talvez precise de C:\MyDartProjects\agg).
    - Suporte a Shading Patterns (degradês complexos) e Tiling Patterns na renderização.

### 3. Motor de Conteúdo (`org.apache.pdfbox.contentstream`) - **Parcialmente Feito**
- **Status**: `PDFStreamEngine` existe, mas precisa ser estendido para suportar a extração de texto e renderização.
- **Falta**: Implementação completa de todos os operadores gráficos para fins de renderização (atualmente foca mais em escrita/leitura básica).

### 4. Validação e Preflight (`org.apache.pdfbox.preflight`) - **Prioridade Média**
Validação de conformidade com PDF/A.
- **Falta**: Todo o pacote `preflight`. Geralmente é um módulo separado no PDFBox.

### 5. Ferramentas de Linha de Comando (`org.apache.pdfbox.tools`) - **Prioridade Baixa**
Wrappers para usar a biblioteca via CLI (Decrypt, Encrypt, ExtractText, PDFToImage).
- **Falta**: Scripts Dart equivalentes aos utilitários Java.

### 6. Testes de Integração
- Embora existam muitos testes unitários, faltam testes de integração "end-to-end" que peguem um PDF complexo, extraiam texto, renderizem e validem o resultado visualmente.

---

## 📋 Próximos Passos Sugeridos

1.  **Implementar `PDFTextStripper`**:
    - Criar `lib/src/pdfbox/text/`.
    - Portar `TextPosition` e a lógica de `PDFTextStreamEngine` (extensão de `PDFStreamEngine`).
    - Implementar o algoritmo de extração e ordenação de texto.

2.  **Implementar Renderização Básica**:
    - Criar `lib/src/pdfbox/rendering/`.
    - Implementar um `PageDrawer` que desenhe em um `Image` do `package:image`.
    - Começar com renderização de texto simples e retângulos, depois evoluir para imagens e curvas.

3.  **Refinar Assinatura Digital**:
    - Garantir que a criação de assinaturas (`saveIncremental`) esteja gerando o hash e o byte range corretamente com exemplos reais de certificados `.p12`.

4.  **Manutenção Contínua**:
    - Continuar rodando `dart analyze` e corrigindo warnings.
    - Adicionar mais testes de regressão para o `PDFMergerUtility` recém-portado.

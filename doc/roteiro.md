# Roteiro de Portabilidade PDFBox para Dart (Status: Novembro 2025)

### referencias de jbig2
https://github.com/agl/jbig2enc
https://github.com/zdenop/jbig2enc-samples
https://github.com/ocrmypdf/OCRmyPDF/issues/748
https://github.com/anotatta/jbig2enc


### referencias de JPEG2000 para poder copiar testes e implementar estes testes em dart e tem que portar tambem o C:\MyDartProjects\pdfbox_dart\jj2000\src\main\java\ucar\jpeg\colorspace o encoder tambem C:\MyDartProjects\pdfbox_dart\jj2000\src\main\java\ucar\jpeg\jj2000\j2k\encoder e o C:\MyDartProjects\pdfbox_dart\jj2000\src\main\java\ucar\jpeg\jj2000\disp
https://github.com/iszak/jpeg2000
https://github.com/uclouvain/openjpeg
https://github.com/GrokImageCompression/grok
https://github.com/aous72/OpenJPH
https://github.com/osamu620/OpenHTJ2K
https://github.com/cureos/csj2k
https://github.com/cinderblocks/CoreJ2K
https://github.com/mozilla/pdf.js.openjpeg
https://github.com/pydicom/pylibjpeg
https://github.com/pydicom/pylibjpeg-openjpeg
https://github.com/BioIntelligence-Lab/openjphpy
https://github.com/khughitt/pyopenjpeg
https://github.com/NeoTech-Software/JPEG2000-Android
https://github.com/iszak/jpeg2000/blob/main/jpc/tests/parse_tests.rs

Rust

Seu projeto (ref.) – iszak/jpeg2000
 – Implementa principalmente o decoding do core JPEG 2000 (ISO 15444-1), com suporte a JP2 container. 
GitHub

C / C++ (núcleo de codec)

uclouvain/openjpeg
 – Codec JPEG 2000 em C, referência oficial ISO/IEC/ITU-T; encode/decode completo de JPEG 2000 Part 1, amplamente usado como base para outras libs. 
GitHub
+1

GrokImageCompression/grok
 – Fork de alto desempenho do OpenJPEG em C++; implementa JPEG 2000 Part 1 e HTJ2K (Part 15), com foco em performance e baixo uso de memória. 
GitHub
+1

osamu620/OpenHTJ2K
 – Implementação open source de HTJ2K (JPEG 2000 Part 15), com decodificação de codestreams Part 1 e Part 15 compatível com o teste de conformidade. 
GitHub

aous72/OpenJPH
 – Implementação de HTJ2K (JPH) em C++, suportando as features principais do JPEG 2000 Part 1; inclui encoder/decoder e pode ser compilado para WebAssembly. 
GitHub
+1

ePirat/gpu_jpeg2k
 – Decoder/encoder JPEG 2000 acelerado por CUDA (GPU), fork de um projeto acadêmico de JPEG2K. 
GitHub

.NET / C#

cureos/csj2k
 – Portável para .NET (PCL); C# port do jj2000, com encode/decode JPEG 2000. 
GitHub

cinderblocks/CoreJ2K
 – Adaptação do CSJ2K para .NET, oferecendo codec JPEG 2000 gerenciado (encode/decode) para várias plataformas .NET. 
GitHub

Java / Android

ThalesGroup/JP2ForAndroid
 – Codec JPEG 2000 (encoder/decoder) para Android baseado em OpenJPEG 2.4.0, empacotado como lib Android. 
GitHub

JavaScript / Web

PantelisGeorgiadis/htj2k-js
 – Decoder HTJ2K (High-Throughput JPEG 2000) em JavaScript para Node.js e browser. 
GitHub
+1

mozilla/pdf.js.openjpeg
 – Wrapper/compilação do OpenJPEG para fornecer decoder JPEG 2000 para o pdf.js (gera openjpeg.js via Emscripten). 
GitHub

Python (usando OpenJPEG/OpenJPH)

pydicom/pylibjpeg
 + pydicom/pylibjpeg-openjpeg
 – Framework Python para decodificação JPEG/JPEG-LS e JPEG 2000; o plugin pylibjpeg-openjpeg é um wrapper de OpenJPEG para decodificar J2K/JP2/HTJ2K. 
GitHub
+1

BioIntelligence-Lab/openjphpy
 – Wrapper Python para OpenJPH, permitindo encode/decode de imagens HTJ2K (JPEG 2000 Part 15). 
GitHub

teknasd/DicomHTJ2K
 – Ferramenta Python para encode/decode de DICOMs com HTJ2K, baseada em OpenJPH + openjphpy. 
GitHub

MATLAB / Pesquisa

osamu620/MatHTJ2K
 – Implementação em MATLAB de JPEG 2000 Part 1 e Part 15 (HTJ2K), alinhada aos testes de conformidade da Parte 4; boa como referência de algoritmos de decoding.

Repos como OpenJPEG e OpenHTJ2K têm baterias enormes de testes de conformidade + regressão + unitários, com um repositório separado só de arquivos de teste (openjpeg-data), cobrindo toda a ISO 15444-4. 
GitHub
+1

O OpenHTJ2K declara explicitamente que o decodificador é “fully compliant with conformance testing defined in ISO 15444-4”, ou seja, ele passa pela suíte oficial de conformidade. 
GitHub

Comparando o estado atual dos projetos:

Mais “pesadamente” testados (muito mais casos, conformance etc.)

uclouvain/openjpeg

osamu620/OpenHTJ2K

GrokImageCompression/grok

Bem testados, mas um degrau abaixo em escala/documentação de testes

aous72/OpenJPH

pydicom/pylibjpeg-openjpeg (em cima do OpenJPEG)

cureos/csj2k

Seu iszak/jpeg2000

Já tem testes (como o parse_tests.rs e possivelmente outros nos crates), mas ainda não está naquele nível de “bateria gigante de conformance + fuzzing + regressão” que esses veteranos têm. O próprio README ainda fala em “add tests / add fuzzing”, o que indica que você mesmo planeja crescer bastante essa parte. 
Muito bem testados (unitário + integração/conformance):

OpenJPEG – referência oficial, grande suíte de conformance, não-regressão e unit tests.

OpenHTJ2K – HTJ2K com conformidade explícita à ISO 15444-4 e dados de conformance no próprio repo.

Grok – boa suíte em tests/ + CI + OSS-Fuzz.

Bem testados, mas num nível um pouco abaixo desses três:

OpenJPH – tem tests/ + CI, mas menos documentação pública sobre conformance.

pylibjpeg-openjpeg – forte em testes Python + cobertura, mas é wrapper do OpenJPEG.

csj2k – vários projetos de teste e codectest, cobrindo múltiplas plataformas.

Pouco testado (pelo que aparece):

iszak/jpeg2000 – não há estrutura evidente de suíte de testes automatizados.

Se você quiser escolher uma base “de ouro” para validar implementação própria (inclusive sua porta em Dart), eu usaria:

OpenJPEG como referência principal (imagens + resultados), e

OpenHTJ2K/Grok para comparar comportamento em HTJ2K.



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

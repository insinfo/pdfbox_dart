# roteiro Validar Porta JJ2000 Java → Dart
A ideia é usar o Java JJ2000 como referência de portabilidade, mas ter OpenJPEG/OpenHTJ2K como “fonte de verdade” numérica. Vamos construir testes em camadas: primeiro vetores sintéticos pequenos (rainbowbars, gradientes), depois comparação Dart × Java × OpenJPEG, depois um subconjunto de conformidade e, por fim, testes em PDFs via pdfbox_dart. Tudo isso com dados de teste pequenos, bem organizados e compartilhados entre Java e Dart.
java C:\MyDartProjects\pdfbox_dart\jj2000
dart C:\MyDartProjects\pdfbox_dart\lib\src\jj2000
openjpeg C:\MyDartProjects\pdfbox_dart\openjpeg

continue trabalhando não pare ate concertar a implementação dart

Steps
Definir oráculos de referência: usar OpenJPEG/OpenHTJ2K como verdade numérica e Java JJ2000 (jj2000/src/main/java/ucar/jpeg/...) como referência de porta, documentando essa política em TODO.md/doc/jj2000.md.
Criar estrutura comum de dados de teste em resources/j2k_tests/ (subpastas synthetic/, conformance_subset/, pdf/) com BMP/PGM/PPM originais, .j2k/.jp2 gerados e meta.json com metadados + tolerâncias.
Gerar vetores sintéticos pequenos (rainbowbars, gradientes, checkerboard, 8/16 bits) via ImageMagick/ scripts e codificar com OpenJPEG; salvar também a imagem referência decodificada (reference.pgm/ppm) e documentar no README dessa pasta.
Adicionar testes Dart em jj2000 (decoder_golden_vectors_test.dart, decoder_cross_implementation_test.dart) que leem resources/j2k_tests/..., decodificam com jj2000 e comparam com as referências (igualdade total para lossless, PSNR/MSE com limite para lossy).
Adicionar testes Java JUnit em java (GoldenVectorDecodeTest, ConformanceSubsetTest) que usam o mesmo resources/j2k_tests/... para decodificar com o JJ2000 Java e checar contra as mesmas referências OpenJPEG.
Selecionar um subconjunto pequeno  de suites de conformidade (OpenJPEG/OpenHTJ2K), copiar só alguns casos representativos para resources/j2k_tests/conformance_subset/ ou criar scripts que baixam/geram esses arquivos, e amarrar isso em testes Dart/Java adicionais.
Criar scripts em scripts (PowerShell/Dart) para: gerar vetores sintéticos, chamar opj_compress/opj_decompress/OpenHTJ2K/Grok, calcular PSNR/MSE e atualizar meta.json/reference.* sem precisar fazer isso manualmente toda vez.
Planejar a extensão para o encoder (jj2000/j2k/encoder) e colorspace portados: testes unitários de mapeamento de cores (Java vs Dart) com vetores pequenos, e testes de encoder onde Dart gera .j2k/.jp2, OpenJPEG/Grok/Java decodificam e comparam com a imagem original.
Further Considerations
Para começar simples, faz sentido priorizar: (A) rainbowbars + alguns gradientes lossless/lossy, (B) comparar só Dart vs OpenJPEG; depois incluir Java/Grok?
Você prefere manter todos os arquivos de teste (BMP/JP2/PGM) dentro deste repo ou ter um repositório separado só de dados (tipo pdfbox_dart-testdata) para não inflar demais o principal?
Sobre portar testes de outros projetos (Rust jpeg2000, csj2k): focar primeiro em copiar apenas ideias/casos (codestreams mínimos escritos à mão) em vez de arquivos binários grandes; você quer um plano mais detalhado só para essa parte de “testes de parsing/erro”

## 2025-11-21 — Instrumentação recente
- Com `dart run scripts/compare_j2k_reference.dart resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2 resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless_reference.pgm --instrument` geramos `jj2000_inst_latest.log` com os novos campos de `_computeStep`.
- LL (res=0, band=0) está saindo com `magBits=15`, `shiftBits=16`, `expBits=14`, `baseStep=1.15394592e-4` e `step=4.5076e-7`; os floats reconstruídos ficam em `[-2.97, 1.48]`, o que explica o teto ~118 após o level shift +128.
- As bandas de resolução 5 high-pass mostram `shiftBits=20` e passos na casa de `1e-6`, ou seja, a escala se mantém muito baixa ao longo da pirâmide; ainda não sabemos se o Java gera `baseStep` diferente ou aplica outro ganho antes da inversa.
- Próximo passo: instrumentar o JJ2000 Java com os mesmos logs para comparar `magBits`, `baseStep` e `shiftBits`. Isso vai confirmar se o problema está em `QuantStepSizeSpec`/`StdDequantizerParams` ou em algum fator de ganho específico do port.
- 2025-11-21 (noite): Mesmo após portar o unstuffing do `PktHeaderBitReader`, o pacote `tile=0 res=5 band=2` continua vindo com `len=[7]` (Java usa 19 bytes). Adicionamos logs no `PktDecoder` para capturar `newTruncPoints`, `lblock`, `baseBits` e `len` por bloco quando `DecoderInstrumentation` estiver ativo; próximo passo é re-rodar o gradiente para ver onde os bits estão sendo descartados.
## 2025-11-21 — Pacote LL inspeção bruta
- Conferimos o codestream direto com `Format-Hex` (`resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2`, offsets `0x13D-0x145`) e só existem 7 bytes úteis (`E1 8C 0A A3 A5 81 DF`) antes do `EOC (FFD9)`.
- Ou seja, tanto Dart quanto Java só podem ler 7 bytes para `tile=0 res=5 band=2`, e o que parecia truncamento é o comportamento esperado do próprio arquivo.
- O foco volta para a etapa de dequantização / reconstrução: LL sai com `magBits=15` e `shiftBits=16`, derrubando os níveis para ~101.5 antes do level shift. Precisamos instrumentar o Java JJ2000 (ou trocar amostras com o `StdDequantizer`) para confirmar se ele aplica exatamente os mesmos passos ou se há algum ganho extra antes da inversa.
- Próximos passos imediatos:
	1. Habilitar `DecoderInstrumentation` no Java (`DecoderInstrumentation.configure(true)` antes do decode) e capturar `StdDequantizer`/`InvWTFull` logs do mesmo arquivo.
	2. Comparar bloco a bloco (principalmente `res=0 band=0` e `res=5` high-pass) para ver onde os coeficientes divergem.
	3. Caso o Java reporte valores maiores, inspecionar `rb`, `magbits` e a normalização usada para `shiftBits`/`step` para portar a mesma lógica.
## 2025-11-22 — Comparação Dart × Java (gradient_8bit_lossless)
- Java CLI com `-instrument on` reproduziu exatamente os seis pacotes esperados (`pktIdx=0-5` nos mesmos offsets) e reportou os mesmos `magBits`, `shiftBits`, `baseStep` e `Derived=false` em todas as bandas observadas.
- Para `res=0 band=0` e `res=1 band=2` os `StdDequantizer float preview` valores batem entre Dart e Java (`101.4882` vs `101.4882`, `2.304810`/`-62.521606`), confirmando que LL + primeira banda high-pass estão alinhadas.
- A primeira divergência aparece em `res=2 band=2`: o Java mostra os quatro primeiros coeficientes quantizados como `-2142830592` (após o decode) e floats `-4.160156`, enquanto a versão Dart mantém `6225920, 8192000, 12517376, 12517376` → `5.566406, 7.324219, 11.191406, 11.191406`. Ou seja, os dados já chegam diferentes *antes* da dequantização.
- Como `skipMSBP=5`, `nTrunc=25` e o payload (12 bytes) batem, o erro deve estar no fluxo do `StdEntropyDecoder`/`CodeBlock` no Dart (provavelmente no peeling de stripes ou no parse das passagens MQ) e não em `QuantStepSizeSpec`.
- Próximos passos: instrumentar o Dart `StdEntropyDecoder` para despejar o mapa de significância/sinal do bloco `res=2 band=2` e comparar com o trace granular do Java (`ZC/SC/MR` por k). Se necessário, diffar a implementação do `StripeDecoder`/`SigPropPass` para esse caso de `cblk=64x64` e `skipMSBP>=5`.
- Fizemos exatamente isso: o novo logger por passagem mostra que as duas primeiras linhas do bloco (`rows=0,0,0,0 | 0,0,0,0 | …`) permanecem zeradas até o bitplane 22, enquanto o Java já marca significância para os mesmos índices logo no primeiro cleanup (vide `StdEntropyDecoder] [TRACE] cleanuppass ZC R1 k=32…`). Isso confirma que os símbolos MQ estão sendo consumidos, mas aplicados nos lugares errados — possivelmente por causa do laço `for (s = nstripes-1; s >= 0; s--)` escrevendo em ordem inversa (invertendo stripes ao gravar em `data`).
- Os valores negativos “saturados” do Java (≈ -2.14e9) aparecem no Dart apenas na última linha do bloco, reforçando a hipótese: o código está percorrendo os stripes de baixo para cima, mas o buffer `data` é linearizado de cima para baixo. Precisamos alinhar os ponteiros `sk`/`sj` na rotina de stripes (provavelmente ajustar `var sk = cblk.offset; var sj = sscanw + 1; for (var s = 0; s < nstripes; s++ …)` ou reescrever para seguir o mesmo sentido do Java).

porque voce portou do java para dart de forma tão diferente agora a implementacao dart esta bugada é culpa sua era para ter mantido o mais proximo possivel mantendo a mesma hierarquia de diretorios, nomes de classe, nomes de metodo que nao tenha sobrecarga etc agora esta ai com o codigo bugado seu bosta  C:\MyDartProjects\pdfbox_dart\jj2000\src\main\java\ucar\jpeg\jj2000\j2k\entropy\decoder\StdEntropyDecoder.java 
voce é muito burro siquer consegue gerar arquivos de logs iguais em dart e java
REFATORE o codigo dart para que tenha alinhamento com a versão java ou seja mesma
estrutura de diretorios, nomes de arquivos, nomes de classe e nomes de metodo desdeque não tenha sobrecarga de metodos é claro e gere o mesmo tipo de log e principalmente que funcione igual so pare quando estiver tudo igual ao java

cd c:/MyDartProjects/pdfbox_dart; java -cp jj2000/target/jj2000-5.5-SNAPSHOT.jar ucar.jpeg.jj2000.j2k.decoder.CmdLnDecoder -instrument on -i resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2 -o build/grad_final_java_out.pgx 2>&1 | Tee-Object -FilePath temp/java_gradient_inst.log

cd c:/MyDartProjects/pdfbox_dart; python scripts/compare_pgm.py build/java_gradient_out.pgm resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless_reference.pgm        
max diff 0, min diff 0, avg diff 0.0000, mismatched samples 0

cd c:/MyDartProjects/pdfbox_dart; dart run scripts/decode_to_bmp.dart resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2 build/dart_gradient_out.pgm 

verifique se a implementação esta seguindo a especificação corretamente C:\MyDartProjects\pdfbox_dart\lib\src\ucar\jpeg\jj2000 https://www.academia.edu/2822519/The_JPEG_2000_still_image_compression_standard https://www.ece.uvic.ca/~frodo/publications/jpeg2000.pdf https://pt.scribd.com/document/82996772/JPEG-2000-Standard

 O que funciona:
icon32.jp2 - imagem muito simples (30 bytes comprimidos)
Arquitetura geral do código está correta
Int32Utils e reconstrução de coeficientes funcionam
❌ O que NÃO funciona:
Todas as imagens de teste geradas (gradient, checkerboard, circles, text, etc.)
Imagens com bitstreams maiores/mais complexos
Resultado: ruído grave visível nos screenshots
🎯 Causa mais provável:
Bug no MQDecoder relacionado a:
C:\MyDartProjects\pdfbox_dart\jj2000\src\main\java\ucar\jpeg\jj2000\j2k
Leitura incorreta do bitstream
Byte stuffing (0xFF 0x00) com problema
Estado não resetado corretamente entre passes
📁 Arquivos para você verificar visualmente:
comparison.html - Compare lado a lado
checkerboard_64_dart_decoded.png - Ruído visível
checkerboard_64_openjpeg_decoded.png - Correto
DEBUG_SUMMARY.md - Resumo técnico completo
O próximo passo é debugar o mq_decoder.dart comparando byte-a-byte com a implementação Java ou adicionar logging extensivo para encontrar onde os símbolos decodificados divergem.
C:\MyDartProjects\pdfbox_dart\test_images
Excelente ponto! Você está absolutamente certo - precisamos começar pelos fundamentos. Vou criar testes unitários rigorosos para as operações mais básicas que o MQDecoder e outros decoders dependem.
C:\MyDartProjects\pdfbox_dart\test\jj2000
Vamos começar testando as operações bitwise fundamentais e classes utilitárias:

depois Vou criar testes unitários rigorosos para cada componente do decoder, comparando o comportamento entre Java e Dart. Começarei pelos componentes mais críticos: MQDecoder, ByteToBitInput e StdEntropyDecoder.

# RESUMO DO DEBUG: Decoder Dart Produzindo Ruído

## Problema Identificado
- **Icon32.jp2** (30 bytes comprimidos): ✓ FUNCIONA PERFEITAMENTE
- **Imagens de teste** (700+ bytes comprimidos): ✗ FALHA COM RUÍDO GRAVE

## Evidências
1. Imagens pequenas/simples funcionam
2. Imagens maiores/complexas produzem ruído catastrófico  
3. O state array ESTÁ sendo limpo corretamente (linha 240)
4. Int32Utils está correto (testado isoladamente)
5. Ambos os tipos de imagem usam RCT, 3 componentes, mesmos parâmetros

## Hipóteses Restantes
O bug está em uma destas áreas:

### 1. MQDecoder - Leitura de Bitstream (MAIS PROVÁVEL)
- Problema com byte stuffing (0xFF seguido de 0x00)
- Problema com término de segmentos
- Estado do MQ não sendo resetado corretamente entre passes

### 2. ByteToBitInput - Buffer de Entrada
- Overflow ou underflow ao ler bytes
- Problema com tamanho de segmento

### 3. StdEntropyDecoder - Passes de Codificação
- Problema em passes complexos (múltiplos bit planes)
- Problema com code-blocks maiores

## Próximos Passos Sugeridos

###  OPÇÃO A: Comparar MQDecoder bit-a-bit com Java
Adicionar logging detalhado para comparar:
- Bytes lidos do bitstream
- Símbolos decodificados
- Estado interno (c, a, ct)

### OPÇÃO B: Testar com arquivo Java intermediário
Usar o TestDecoder.java para extrair:
- Todos os símbolos decodificados
- Comparar com Dart símbolo por símbolo

### OPÇÃO C: Reduzir caso de teste
Criar imagem MÍNIMA que falha (ex: 8x8 solid color)
- Mais fácil de debugar manualmente
- Menos dados para analisar

## Arquivo de Teste Recomendado
Use `gradient_32_openjpeg.jp2` para debug:
- Pequeno (32x32)
- Falha consistentemente
- Padrão visual simples (gradiente)

## Comando para Teste Rápido
```bash
dart run scripts/decode.dart -i test_images/visual_tests/gradient_32_openjpeg.jp2 -o test.ppm
```

## Status
❌ **BLOCKER CRÍTICO** - Decoder não funciona para casos reais
✅ Arquitetura correta, bug específico isolado
🎯 Foco: MQDecoder e leitura de bitstream

# JJ2000 Test Parity
sempre responda em portugues
a versão java esta em C:\MyDartProjects\pdfbox_dart\jj2000
 versão dart aqui C:\MyDartProjects\pdfbox_dart\lib\src\jj2000
 a versão java é a versão que funciona perfeitamente 
 ou seja a versão java é a fonte de verdade
 se um teste java falhar é porque o teste esta errado
 se a versão dart der resultado diferente é porque a versão dart esta errada e tem que ser corrigida 
 a versão portada de java para dart esta com bug não esta decodificando JPEG 2000 corretamente,
 o foco é implementar testes simultaneamente em java e dart afim de descobrir onde a versão dart esta errada
e concertar a versão dart

- [ ] Decoder rainbowbars integration (Dart) - verificar BMP nao-preto.

## Problemas Conhecidos
- [ ] **StdEntropyDecoder cleanupPass/paridade** – A porta do cleanup/RAW MR (`_cleanupPass`, `_rawMagRefPass`) foi concluída replicando o Java, mas ainda precisa de validação cruzada com fixtures reais para garantir que o mesmo mapa de significância e detecção de erros seja produzido.

## Em Andamento
- [ ] Levantar testes existentes em `jj2000/src/test` (Java).
- [ ] Mapear testes equivalentes em `lib/src/ucar/jpeg/jj2000` (Dart) C:\MyDartProjects\pdfbox_dart\test\jj2000.
- [ ] Executar suites Java relevantes via `mvn -pl jj2000 test`.
- [ ] Executar suites Dart relevantes via `dart test test/jj2000/`.
- [ ] Registrar diferencas observadas entre saidas Java e Dart.
- [] Abrir issues para divergencias nao resolvidas.
- [ ] Investigar divergencia entre  (Dart) java

## Mapeamento Java -> Dart
# como gerar imagens para testes do decoder
magick -size 32x32 xc:black  -draw "fill red   rectangle 0,0   10,31"  -draw "fill green rectangle 11,0  21,31"  -draw "fill blue  rectangle 22,0  31,31" barras_rgb.bmp

 magick barras_rgb.bmp barras_rgb.jp2

scripts utilizados para depurar o jj2000 port
 PS C:\MyDartProjects\pdfbox_dart\scripts\jj2000> ls

    Directory: C:\MyDartProjects\pdfbox_dart\scripts\jj2000

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---          23/11/2025    01:21           4247 compare_decoded_images.dart
-a---          22/11/2025    01:31           9685 compare_j2k_reference.dart 
-a---          21/11/2025    17:47           2848 compare_pgm.py
-a---          23/11/2025    01:39           2910 compare_ppm.dart
-a---          23/11/2025    01:47           3868 compare_visual_tests.py    
-a---          22/11/2025    01:31           1257 decode_to_bmp.dart
-a---          23/11/2025    01:21            856 decode.dart
-a---          23/11/2025    01:23           8346 generate_test_images_v2.ps1
-a---          23/11/2025    01:46           8270 generate_visual_tests.ps1
-a---          20/11/2025    15:41           1530 gradiente_8_vs_12.bat
-a---          21/11/2025    16:27           1209 j2k_generate_gradient_8bit.ps1
-a---          21/11/2025    16:26           1030 j2k_generate_rainbowbars.ps1
-a---          23/11/2025    01:40           2750 quick_compare.dart
-a---          23/11/2025    01:36           3842 test_reconstruction.dart

PS C:\MyDartProjects\pdfbox_dart\scripts\jj2000>
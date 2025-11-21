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
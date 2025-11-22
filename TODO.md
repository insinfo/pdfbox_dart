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

## Em Andamento
- [ ] Levantar testes existentes em `jj2000/src/test` (Java).
- [ ] Mapear testes equivalentes em `lib/src/ucar/jpeg/jj2000` (Dart) C:\MyDartProjects\pdfbox_dart\test\jj2000.
- [ ] Executar suites Java relevantes via `mvn -pl jj2000 test`.
- [ ] Executar suites Dart relevantes via `dart test test/jj2000/`.
- [ ] Registrar diferencas observadas entre saidas Java e Dart.
- [ ] Abrir issues para divergencias nao resolvidas.
- [ ] Investigar divergencia entre  (Dart) java

## Mapeamento Java -> Dart
# como gerar imagens para testes do decoder
magick -size 32x32 xc:black  -draw "fill red   rectangle 0,0   10,31"  -draw "fill green rectangle 11,0  21,31"  -draw "fill blue  rectangle 22,0  31,31" barras_rgb.bmp

 magick barras_rgb.bmp barras_rgb.jp2
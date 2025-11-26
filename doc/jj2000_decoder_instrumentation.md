# CLI de Instrumentação do Decoder JJ2000

Esta nota resume as opções de linha de comando disponíveis no `CmdLnDecoder` (Java) e no decoder Dart equivalente. Elas permitem ligar logs detalhados do pipeline de decodificação, restringir a instrumentação a blocos específicos, gerar traces do MQ-coder e capturar snapshots da banda LL após a transformada inversa.

## Opções relevantes

| Opção             | Valores                               | Efeito                                                                                                   | Observações |
|-------------------|----------------------------------------|----------------------------------------------------------------------------------------------------------|-------------|
| `-instrument`     | `on` \| `off` (padrão `off`)            | Liga o `DecoderInstrumentation`, habilitando logs de passes (cleanup, mag-ref, sig-prop), pacotes, etc. | Ative antes de outras opções; sem isso nada é gravado. |
| `-inst_block`     | `<tile,comp,res,band,cblkY,cblkX>`     | Restringe os logs ao bloco informado (use `-1` como coringa em qualquer campo).                          | Ex.: `-inst_block "0,2,2,0,0,0"` traça o bloco Y=0 X=0 da banda 2 na resolução 2 do tile 0, componente 2. |
| `-inst_mq_log`    | `<caminho/para/log.txt>`               | Escreve o trace completo do MQ-coder (A, C, CT, contexto, símbolo) no arquivo indicado.                   | O arquivo é recriado a cada execução; garante diretório existente. |
| `-inst_ll_dump`   | `<prefixo/arq>`                        | Exporta snapshots JSON da banda LL (antes/depois da inversa) para arquivos `<prefixo>_[pre|post].json`.   | Use junto com `-inst_ll_tile_index`, `-inst_ll_component` e `-inst_ll_stage`. |
| `-inst_ll_tile_index` | inteiro (`0` padrão)              | Seleciona o índice do tile usado nas capturas LL.                                                        | Usa ordenação raster (tileY * tilesX + tileX). |
| `-inst_ll_component`  | inteiro (`0` padrão)              | Define qual componente terá a banda LL despejada.                                                        | Tipicamente 0 para luminância / único canal. |
| `-inst_ll_stage`  | `pre` \| `post` \| `both` (padrão `post`) | Controla se o snapshot LL é capturado antes da inversa (posterior ao StdDequantizer), depois, ou ambos.  | `pre` ajuda a depurar coeficientes quantizados; `post` mostra pixels reconstruídos antes do level shift. |

## Exemplos de uso

### Java CmdLnDecoder
```powershell
cd c:/MyDartProjects/pdfbox_dart
java -cp jj2000/target/jj2000-5.5-SNAPSHOT.jar `
  ucar.jpeg.jj2000.j2k.decoder.CmdLnDecoder `
  -i resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2 `
  -o build/grad_final_java_out.pgx `
  -instrument on `
  -inst_block "0,0,2,2,0,0" `
  -inst_mq_log temp/java_mq_trace.log
```

### Decoder Dart (scripts/compare_j2k_reference.dart)
```powershell
cd c:/MyDartProjects/pdfbox_dart
dart run scripts/compare_j2k_reference.dart `
  resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless.jp2 `
  resources/j2k_tests/synthetic/gradient_8bit/gradient_8bit_lossless_reference.pgm `
  --instrument --inst-block "0,0,2,2,0,0" --inst-mq-log temp/dart_mq_trace.log
```

As flags camel-case expostas na CLI Dart são traduzidas internamente para os mesmos parâmetros (`instrument`, `inst_block`, etc.), garantindo paridade com o comportamento do `CmdLnDecoder` Java.

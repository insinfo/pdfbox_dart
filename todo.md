# JJ2000 Dart Port Verification Plan
a implementação java esta em C:\MyDartProjects\pdfbox_dart\jj2000
o port dart esta em C:\MyDartProjects\pdfbox_dart\lib\src\ucar
## Objetivo
Garantir que cada arquivo em `lib/src/ucar/jpeg/jj2000` esteja alinhado com sua implementação Java equivalente em `jj2000/src/main/java/ucar`, respeitando as limitações da linguagem Dart (ex.: ausência de sobrecarga).
objetivo final  corrigir a implementação dart para que fique correta como a versão java, para garantir aliamento com a implementação java pode ser necessario implementar testes unitarios e de integração do lado java tambem e comporar com o lado dart
## Estratégia Geral
1. **Mapeamento 1:1** – Confirmar que cada arquivo Dart tenha um Java correspondente (ajustando caminhos quando o Dart inclui `jj2000` no namespace) e vice-versa.
2. **Comparação Estrutural** – Para cada par:
- é vital que os nomes de metodos batem com o java
   - Verificar se os nomes de classes batem é vital.
   - Listar construtores e métodos públicos/protegidos no Java e checar presença em Dart (ignorar sobrecargas múltiplas, mas garantir versões adaptadas).
3. **Análise de Implementação** – Rever corpo dos métodos críticos para garantir mesma lógica: estados internos, cálculos, tratamento de exceções, uso de constantes.
4. **Correções Incrementais** – Ajustar arquivo por arquivo, mantendo commits focados em pacotes/past as específicas.
5. **Registro de Progresso** – Atualizar esta lista conforme cada pacote for validado.

## Ordem de Verificação
1. `colorspace/boxes` (arquivos menores, usados por todo o fluxo JP2).
2. `colorspace` (mappers e lógica de detecção de espaço de cor).
3. `icc` (perfis ICC e LUTs).
4. `j2k/fileformat`, `j2k/codestream` (estrutura do codestream, essencial para compatibilidade).
5. `j2k/image` (fontes e sinks de bloco).
6. `j2k/entropy` (codificadores/decodificadores EBCOT).
7. `j2k/quantization` e subpastas.
8. `j2k/wavelet` (analysis/synthesis).
9. `j2k/roi`, `j2k/util`, `j2k/io`.
10. Demais pacotes (`colorspace/mapper`, `disp`, etc.).

## Checklist por Arquivo
- [ ] Arquivo Dart existe e aponta para mesmo caminho lógico do Java.
- [ ] Nome(s) de classe coincidem.
- [ ] Construtores presentes (adaptando sobrecargas via fábricas/named constructors se necessário).
- [ ] Métodos públicos/estáticos portados.
- [ ] Campos estáticos/constantes equivalentes.
- [ ] Diferenças intencionais documentadas em comentário breve.
- [ ] Testes ou fixtures atualizados (quando aplicável).

## Próximos Passos Imediatos
1. **colorspace/boxes** – Revisar `ChannelDefinitionBox`, `ComponentMappingBox`, `ColorSpecificationBox`, `ImageHeaderBox`, `JP2Box`, `PaletteBox`. Registrar divergências e corrigir. ✅ Revisado em 2025-11-23; campos/nomes alinhados e consistência de `JP2Box`/`ColorSpace` reforçada.
2. **colorspace** – Validar `ColorSpace`, `ColorSpaceMapper` e derivados, garantindo compatibilidade de API pública usada pelo decodificador. ✅ `ColorSpace` e `ColorSpaceMapper` revisados; fábrica agora instancia `ICCProfiler`, `EnumeratedColorSpaceMapper`, `PalettizedColorSpaceMapper` e `SYccColorSpaceMapper` conforme a versão Java.

## Notas da revisão (2025-11-23)
- `ColorSpaceMapper.dart` atualizado para validar parâmetros (`ParameterList.checkListSingle`) e criar `ICCProfiler`, `EnumeratedColorSpaceMapper`, `PalettizedColorSpaceMapper` ou `SYccColorSpaceMapper` conforme o método/corespace reportado. Paletas agora caem direto no mapper correto.
- `EnumeratedColorSpaceMapper.dart`, `PalettizedColorSpaceMapper.dart`, `SYccColorSpaceMapper.dart` e `Resampler.dart` foram portados do Java, respeitando a lógica de amostragem e conversão (incluindo o resample 2:1 e a matriz sYCC→sRGB). Restam validar com fixtures.
- LUTs de 8/16 bits citadas no Java (`LookUpTable8*`, `LookUpTable16*`) foram portadas para `lib/src/ucar/jpeg/jj2000/icc/lut` (bases + variantes Gamma/Interp + `LookUpTable16LinearSRGBtoSRGB`). Falta validar na prática onde cada uma é utilizada pelo profiler, mas a paridade estrutural com o Java agora existe.

## Notas da revisão (2025-11-24)
- Criados `LookUpTable8.dart`, `LookUpTable8Gamma.dart` e `LookUpTable8Interp.dart`, espelhando as curvas 8-bit do Java e garantindo normalização/clamping apropriados em Dart (`Uint8List`).
- Adicionados `LookUpTable16.dart`, `LookUpTable16Gamma.dart`, `LookUpTable16Interp.dart` e `LookUpTable16LinearSRGBtoSRGB.dart`, utilizando `Uint16List` para manter os valores unsigned requeridos pelos perfis ICC.
- Conferido em `ICCProfiler`/`MatrixBasedTransformTosRGB`/`MonochromeTransformTosRGB` que apenas os LUTs FP/32 e o LUT curto interno são usados na etapa final, assim como no Java; comentários do transform foram atualizados para refletir isso.

## Notas da revisão (2025-11-25)
- `Decoder.dart` passou a instanciar `ChannelDefinitionMapper`, `Resampler`, `PalettizedColorSpaceMapper` e o mapper ICC/enumerado exatamente como o Java, respeitando JP2/`nocolorspace` e reaproveitando `ColorSpace.isOutputSigned` para as checagens de PPM/PGM.
- `HeaderDecoder.dart` expõe as fábricas `createChannelDefinitionMapper`, `createResampler`, `createPalettizedColorSpaceMapper` e `createColorSpaceMapper`, mantendo paridade com a API Java.
- O CLI aceita `nocolorspace`/`colorspace_debug` e agora delega corretamente as opções prefixadas (`B*`, `C*`, `R*`) aos módulos especializados, evitando falsos positivos em `ParameterList.checkList`.
- Alinhada a lista de prefixos válidos do `Decoder` com a versão Java (`Q*`, `M*`, `H*`, `I*`), adicionando as constantes `optionPrefix`/`OPT_PREFIX` faltantes para `Dequantizer`, `InvCompTransf`, `HeaderDecoder` e `ColorSpaceMapper`.
- O parâmetro `comp_transf` voltou para o CLI, permitindo desabilitar o estágio `InvCompTransfImgDataSrc` (fica pass-through quando `off`) exatamente como no Java.
- O parâmetro `res` voltou a ser exposto e propagado ao `BitstreamReaderAgent`, permitindo reconstruir níveis reduzidos (via `_initialiseTargetResolution`) tal como no decoder Java.

## Notas da revisão (2025-11-26)
- `FileBitstreamReaderAgent` ganhou testes adicionais para `ncb_quit`, `l_quit`, `poc_quit`, `one_tp` e `res`, garantindo que as opções de parada/ordenação do Java tenham paridade comprovada no Dart.
- `ParameterList` recebeu novos testes cobrindo `propertyNames` com defaults e o parser de arquivos (`loadFromString`), reduzindo risco de divergências com o comportamento da CLI Java.

## Notas da revisão (2025-11-27)
- `HeaderDecoder` agora valida rigorosamente `scod/scoc`, ordem de progressão e o flag MCT, espelhando o comportamento da versão Java e evitando aceitar marcadores inválidos.
- Novos testes em `test/jj2000/j2k/codestream/reader/header_decoder_test.dart` cobrem contagem de camadas zero, ordens de progressão fora do intervalo e bits reservados. O teste de integração `decoder_test.dart` foi atualizado para usar um COD válido (NL >= 1).
- Corrigido o import de `InverseWT` (case-sensitive) para garantir que a fábrica `InverseWT.createInstance` retorne `InvWTFull` sem duplicar tipos; `inv_wt_full_test.dart` voltou a compilar e proteger o caminho do factory.

## Notas da revisão (2025-11-28)
- `DecoderSpecs.basic` agora instancia `RectROISpec`, permitindo expor retângulos configurados antes da leitura do codestream.
- `HeaderDecoder.parseRgnMarker` limpa automaticamente qualquer ROI retangular associada ao tile/componente assim que um `RGN` define o max-shift, reproduzindo o efeito de sobrescrever o ROI no Java.
- Novos testes em `test/jj2000/j2k/codestream/reader/header_decoder_test.dart` garantem que os retângulos sejam descartados tanto para escopos globais quanto por tile quando um shift do codestream chega.
- Portado `FileFormatWriter` para `lib/src/ucar/jpeg/jj2000/j2k/fileformat/writer`, gerando o cabeçalho JP2 mínimo exatamente como no Java (caixas Signature/Ftyp/JP2Header/BPCC condicionais).
- `file_format_reader_test.dart` ganhou um caso integrando o writer ao reader, garantindo que o wrapper JP2 escreva offsets corretos e preserve o codestream.

## Notas da revisão (2025-11-29)
- Revisados `HeaderInfo.dart`, `CoordInfo.dart`, `CBlkCoordInfo.dart`, `PrecCoordInfo.dart`, `PrecInfo.dart` e `codestream/reader/CBlkInfo.dart`, confirmando paridade estrutural com o Java (campos, construtores e `toString()` informativos) e documentando o uso dos mapas `SOT/TLM` recém-portados.
- `HeaderInfoSIZ` recebeu cobertura direta em `test/jj2000/j2k/codestream/header_info_test.dart`, validando `getCompImgWidth/Height`, `getMaxComp*`, `getNumTiles`, sinalização original e bit-depths exatamente como o Java calcula via `ceil()`.
- O mesmo teste exercita `HeaderInfo.populateRoiSpecs`, garantindo que shifts vindos de `RGN` sejam refletidos em `MaxShiftSpec` e que as entradas retangulares correspondentes em `RectROISpec` sejam anuladas apenas para os escopos afetados, preservando ROIs não tocadas.

## Notas da revisão (2025-11-30)
- Adicionado `test/jj2000/j2k/codestream/reader/bitstream_reader_agent_geometry_test.dart`, cobrindo `getImgWidth/Height`, `getTileWidth/Height`, `getCompImg*`, `getTileComp*` e `getResUL*` para múltiplos níveis de resolução, tiles truncados e componentes subsampleados. O teste evidencia o mesmo contrato de índices (RL mínimo = menor resolução, RL máximo = full-res) usado no Java, evitando regressões silenciosas na matemática base do `BitstreamReaderAgent`.

## Notas da revisão (2025-12-01)
- `test/jj2000/entropy/byte_input_rigorous_test.dart` foi reescrito para usar apenas `readBit`, introduzindo helpers (`_readBits`, `_readAlignedBytes`) que permitem reconstruir bytes sem depender de uma API inexistente no Java. Os casos críticos agora validam explicitamente que um `0xFF` consome apenas 7 bits do próximo byte, alinhando os testes com a semântica de bit stuffing original.
- `dart analyze test/jj2000` e `dart test test/jj2000/entropy/byte_input_rigorous_test.dart` executados para garantir que a suíte de regressão capture divergências reais sem requerer novos métodos na porta Dart.

## Notas da revisão (2025-12-02)
- `test/jj2000/byte_input_buffer_test.dart` ampliado para cobrir `setByteArray` com offset negativo (mesma instância), realocação de janela com buffer explícito, validação de slices inválidas e cenários de `addByteArray` que exigem tanto compactação quanto realocação do armazenamento quando o acréscimo excede a capacidade. Isso garante que o buffer Dart replique as transições de segmento esperadas pelo decoder Java.
- `dart analyze test/jj2000` e `dart test test/jj2000/byte_input_buffer_test.dart` rodados para comprovar que as novas verificações permanecem alinhadas com o restante da suíte.

## Notas da revisão (2025-12-03)
- `test/jj2000/entropy/byte_to_bit_input_test.dart` agora cobre explicitamente os caminhos de `checkBytePadding`, diferenciando entre padrões alternados válidos (0xAA) e casos inválidos (bytes extras ≥ 0x80 ou sem o preenchimento 0-1-0-1 esperado). Isso documenta o contrato rígido herdado do JJ2000 para segmentos MQ terminados.
- `test/jj2000/entropy/mq_decoder_rigorous_test.dart` passou a gerar fixtures sintéticos via `MQCoder` (mesmas tabelas da versão Java) para validar as transições `switchLM`, `nextMps` e `nextLps` em contextos distintos, garantindo que o decoder Dart mantenha o estado independente entre contextos mesmo após símbolos LPS.
- `dart analyze test/jj2000` e `dart test test/jj2000/entropy/{byte_to_bit_input_test,mq_decoder_rigorous_test}.dart` executados para confirmar que as novas coberturas estão verdes.

Marcar cada item como concluído diretamente neste arquivo ao finalizar a revisão correspondente.
não crie stubs e sim crie a implementação correta onde não for possivel coloque um comentario // TODO

e va ampliando a cobertura de testes principalmente nas partes basicas e fundamentais pois se não funcionar o basico perfeitamente o complexo jamais vai funcionar

use (ripgrep) rg para busca no codigo fonte

concluir todos os TODOs 
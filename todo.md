# JJ2000 Dart Port Verification Plan
a implementação java esta em C:\MyDartProjects\pdfbox_dart\jj2000
o port dart esta em C:\MyDartProjects\pdfbox_dart\lib\src\ucar
## Objetivo
Garantir que cada arquivo em `lib/src/ucar/jpeg/jj2000` esteja alinhado com sua implementação Java equivalente em `jj2000/src/main/java/ucar`, respeitando as limitações da linguagem Dart (ex.: ausência de sobrecarga).
objetivo final  corrigir a implementação dart para que fique correta como a versão java 
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

Marcar cada item como concluído diretamente neste arquivo ao finalizar a revisão correspondente.
não crie stubs e sim crie a implementação correta onde não for possivel coloque um comentario // TODO

e va ampliando a cobertura de testes principalmente nas partes basica e fundamentais
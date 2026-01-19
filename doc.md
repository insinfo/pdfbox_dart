
# Notas de renderização (pdfbox_dart)

## Fontes Embedadas (Standard 14 Fonts)

Para permitir renderização offline sem dependência de fontes do sistema operacional,
o pdfbox_dart suporta fontes TTF embedadas como Base64 no código Dart.

### Fontes Suportadas

As seguintes fontes Standard 14 do PDF estão disponíveis para embed:

| Arquivo TTF                    | Nomes PDF Mapeados                          |
|-------------------------------|---------------------------------------------|
| helvetica.ttf                 | Helvetica, Arial, ArialMT                   |
| helvetica-bold.ttf            | Helvetica-Bold, Arial-Bold                  |
| times.ttf                     | Times-Roman, Times, TimesNewRoman           |
| CourierPrime-Regular.ttf      | Courier, CourierNew                         |
| CourierPrime-Bold.ttf         | Courier-Bold                                |
| CourierPrime-Italic.ttf       | Courier-Oblique, Courier-Italic             |
| CourierPrime-BoldItalic.ttf   | Courier-BoldOblique                         |
| zapfdingbats.ttf              | ZapfDingbats                                |

### Gerando Fontes Embedadas

Use o script `generate_embedded_fonts.dart` para gerar o arquivo de fontes:

```bash
cd C:\MyDartProjects\pdfbox_dart
dart run scripts/generate_embedded_fonts.dart
```

O script irá:
1. Ler os arquivos TTF de `resources/fontes/`
2. Converter para Base64
3. Gerar `lib/src/pdfbox/pdmodel/font/embedded_fonts.dart`

### Usando as Fontes Embedadas

```dart
import 'package:pdfbox_dart/src/pdfbox/pdmodel/font/embedded_fonts.dart';

// Verificar se a fonte está disponível
if (EmbeddedFonts.hasFont('Helvetica')) {
  // Obter bytes da fonte
  final bytes = EmbeddedFonts.getFontBytes('Helvetica');
  // Usar com TrueTypeFont...
}

// Listar fontes disponíveis
print(EmbeddedFonts.availableFonts);
```

### Integração com FontMapperImpl

O `FontMapperImpl` usa automaticamente as fontes embedadas como fallback
quando as fontes do sistema não estão disponíveis:

```dart
// Em font_mapper_impl.dart
FontBoxFont? getFontBoxFont(String baseFont) {
  // 1. Tenta carregar do sistema
  var font = _tryLoadSystemFont(baseFont);
  if (font != null) return font;
  
  // 2. Fallback para fonte embedada
  final bytes = EmbeddedFonts.getFontBytes(baseFont);
  if (bytes != null) {
    return _loadFromBytes(bytes);
  }
  
  return null;
}
```

### Adicionando Novas Fontes

1. Coloque o arquivo TTF em `resources/fontes/`
2. Adicione o mapeamento em `generate_embedded_fonts.dart`:
   ```dart
   const Map<String, List<String>> fontFileToNames = {
     'minha_fonte.ttf': ['NomePDF1', 'NomePDF2'],
     // ...
   };
   ```
3. Adicione à lista de prioridade se for Standard 14:
   ```dart
   const List<String> priorityFonts = [
     'minha_fonte.ttf',
     // ...
   ];
   ```
4. Execute o script novamente

### Considerações de Tamanho

| Fonte              | TTF (bytes) | Base64 (chars) |
|-------------------|-------------|----------------|
| helvetica.ttf     | ~44 KB      | ~58 KB         |
| helvetica-bold.ttf| ~45 KB      | ~60 KB         |
| times.ttf         | ~47 KB      | ~63 KB         |

O código gerado fica em torno de 500-700 KB com todas as Standard 14 fonts.
Considere embedar apenas as fontes necessárias para seu caso de uso.

---

## Fringe de 1px em retângulos/Type3

É normal aparecer uma “suavização” de ~1px em bordas (topo/direita) ao comparar
com PNGs do PDFBox Java. Isso ocorre quando o retângulo cai em coordenadas
fracionárias no espaço de device, e o rasterizador aplica AA (cobertura parcial).

### Por que diverge do PDFBox Java?

- PDFBox usa Java2D. No Windows, a JVM geralmente renderiza via GDI/DirectWrite
	(depende da JVM e configuração).
- Java2D também aplica AA, mas a quantização/coverage pode divergir do
	rasterizador do `dart_graphics`.

### Abordagem recomendada

- **Manter** a implementação e aceitar pequena tolerância no golden.
- Esse tipo de diferença é esperado entre rasterizadores diferentes.

### Quando for necessário “pixel‑perfect”

Se você precisa bater 100% com o PNG do PDFBox Java:

- Fazer **snap para inteiros** no espaço de device antes de rasterizar.
- Ou **desativar AA** apenas para esses casos (ex.: Type3/fill).

---

## Mecanismo de Fallback de Fontes

### Java (PDFBox Original)

No PDFBox Java, o mecanismo de fallback é gerenciado durante a **inicialização da fonte** (ex: `PDType1Font`), e não no momento do desenho.

1.  **Inicialização**: Ao criar uma fonte, o `FontMappers` tenta encontrar a fonte no sistema.
2.  **Mapeamento**: Se a fonte exata não for encontrada, ele busca uma substituta equivalente ou usa uma padrão (como Helvetica).
3.  **Delegação**: A classe da fonte (ex: `PDType1Font`) delega todas as operações (como `getPath`, `getWidth`) para essa fonte substituta (`genericFont`).
4.  **Transparência**: O `PageDrawer` não sabe que houve fallback; ele apenas usa a fonte que lhe foi entregue, que já está configurada para usar os glifos da substituta.

### Dart (Implementação Atual)

Atualmente, no Dart, implementamos um mecanismo de "rede de segurança" diretamente no `PageDrawer` para lidar com casos onde a fonte falha (especificamente `NonVectorFont` em testes ou fontes corrompidas/ausentes sem mapeamento de sistema):

1.  **Detecção em Tempo de Desenho**: No método `drawGlyph` (ou `_drawWithFallbackFont`), verificamos se a fonte é capaz de fornecer um caminho vetorial (`PDVectorFont`).
2.  **Fallback Forçado**: Se a fonte não for vetorial (ou falhar), o `PageDrawer` intercepta e desenha o glifo usando a **Helvetica embutida** (`EmbeddedFonts.helvetica`).
3.  **Propósito**: Isso garante que o texto apareça (mesmo que com a fonte errada) em vez de falhar ou renderizar nada, emulando o resultado final do Java, mas por um caminho diferente.

### Otimização Futura (TODO)

Para alinhar com a arquitetura do Java e melhorar a performance (evitando verificações a cada renderização de glifo):

1.  **Mover a Lógica**: Implementar um `FontMapper` robusto no Dart que seja invocado no construtor das classes de fonte (`PDType1Font`, `PDTrueTypeFont`, etc.).
2.  **Delegação no Carregamento**: Se a fonte não for encontrada, o próprio objeto de fonte deve carregar a Helvetica embutida como seu "backend" interno de renderização.
3.  **Remover Hack do PageDrawer**: O `PageDrawer` deve apenas chamar `font.getPath()` e obter o caminho correto, sem saber se é a fonte original ou um fallback.


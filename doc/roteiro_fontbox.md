
Ótima iniciativa! Portar o Apache Fontbox para Dart é um projeto ambicioso e muito útil para o ecossistema Dart, especialmente para aplicações que precisam de manipulação avançada de fontes em PDFs ou outros formatos.
Com base nos arquivos que você forneceu, preparei um roteiro detalhado e o esqueleto das classes principais para você começar.
Roteiro Detalhado para Portar o Fontbox para Dart
Este plano divide a tarefa em fases lógicas, começando pelas classes mais básicas e avançando para as mais complexas.
Fase 1: Base e Utilitários
O objetivo aqui é criar as classes de suporte que são usadas por todo o resto do projeto. Elas geralmente não têm dependências complexas.
Estruturas de Dados:
BoundingBox: Uma classe simples para representar caixas delimitadoras. É usada em várias partes do Fontbox.
CmapLookup: Crie a interface (classe abstrata em Dart) para a busca de cmap.
Manipulação de Bytes:
Crie uma classe ou um conjunto de funções auxiliares para substituir java.io.DataInputStream. O Dart usa ByteData e Uint8List do pacote dart:typed_data para isso. Você precisará de métodos para ler short, unsigned short, int, fixed (números de ponto fixo 32-bit), etc. a partir de um buffer de bytes.
Fase 2: Modelos de Dados e Parser AFM (Adobe Font Metrics)
O formato AFM é baseado em texto e um dos mais simples para começar, o que o torna um ótimo ponto de partida para validar sua estrutura de parsing.
Modelos de Dados AFM:
FontMetrics: A classe principal que armazena todas as informações de uma fonte AFM.
CharMetric: Armazena as métricas de um único caractere.
Composite, CompositePart, KernPair, Ligature, TrackKern: Classes de dados que representam partes específicas do AFM.
Parser AFM:
AFMParser: Esta é a classe principal de lógica para esta fase. Você precisará traduzir o código de parsing de Java, que lê um InputStream e o divide em tokens. Em Dart, você pode ler o arquivo como Uint8List e usar String.fromCharCodes para convertê-lo em uma string, e então usar métodos de String (split, indexOf, etc.) para o parsing.
Fase 3: Modelos de Dados e Parsers CFF (Compact Font Format)
Este é um formato binário mais complexo. Você usará intensivamente seus utilitários de manipulação de bytes da Fase 1.
Modelos de Dados CFF:
CFFFont, CFFCIDFont, CFFType1Font: As classes que representam a fonte.
CFFCharset, CFFEncoding: Classes para lidar com o mapeamento de caracteres.
Type1CharString, Type2CharString: Representam as sequências de desenho de glifos.
Parser CFF:
CFFParser: O coração da lógica de parsing do CFF. Esta será uma tradução complexa. Preste atenção especial em como ele lê tipos de dados diferentes (índices, dicionários, números).
Type1CharStringParser, Type2CharStringParser: Parsers específicos para as sequências de desenho de glifos.
Fase 4: Modelos de Dados e Parsers TTF (TrueType Font)
O formato TTF é a base para muitos tipos de fontes modernas.
Tabelas TTF: Crie uma classe para cada tabela principal do TTF.
TTFTable (classe base)
HeaderTable ('head')
NamingTable ('name')
HorizontalHeaderTable ('hhea')
HorizontalMetricsTable ('hmtx')
MaximumProfileTable ('maxp')
OS2WindowsMetricsTable ('OS/2')
PostScriptTable ('post')
CmapTable ('cmap') e CmapSubtable
GlyphTable ('glyf'), GlyphData, GlyphDescription (interface), GlyfSimpleDescript, GlyfCompositeDescript.
Parser TTF:
TTFParser: A classe que lê o diretório de tabelas de uma fonte TTF e inicializa cada parser de tabela.
TTFDataStream: Adapte esta classe para usar ByteData para ler os tipos de dados específicos do TTF.
Fase 5: Fontes de Nível Superior e Testes
Classes de Fonte Principais:
TrueTypeFont / OpenTypeFont: A classe principal que o usuário final irá interagir. Ela amarra todas as tabelas e fornece uma API de alto nível para obter nomes de glifos, caminhos, métricas, etc.
Type1Font: Classe para fontes Type 1.
Testes:
Porte os testes unitários do projeto Java original. Comece com os testes do AFM. Use arquivos de fonte .afm, .pfb, .ttf, .otf da base de código original do PDFBox para garantir que seu port está funcionando corretamente.

Esqueleto das Classes Principais (em Dart)
Aqui está um esqueleto inicial baseado na sua estrutura de projeto e nos arquivos Java. Salve cada bloco de código em seu respectivo arquivo .dart dentro da estrutura de diretórios sugerida.
Dicas de Tradução Java -> Dart:
public class X -> class X
private final Type field; -> final Type _field; (convenção de privacidade com underscore)
public static final String CONST = "v"; -> static const String constName = 'v';
Métodos getX() e setX() em Java geralmente se tornam getters e setters em Dart: Type get x => _x; e set x(Type value) => _x = value;. Para um port direto, você pode manter os métodos se preferir.
Null safety: Tipos que podem ser nulos em Java devem ser marcados com ? em Dart (ex: String?).
throws IOException não é necessário em Dart, pois todas as exceções são "unchecked".
lib/src/util/bounding_box.dart
code
Dart
// lib/src/util/bounding_box.dart

class BoundingBox {
  double lowerLeftX = 0;
  double lowerLeftY = 0;
  double upperRightX = 0;
  double upperRightY = 0;

  BoundingBox();

  BoundingBox.fromValues(
      this.lowerLeftX, this.lowerLeftY, this.upperRightX, this.upperRightY);

  double get width => upperRightX - lowerLeftX;
  double get height => upperRightY - lowerLeftY;

  @override
  String toString() {
    return '[$lowerLeftX, $lowerLeftY, $upperRightX, $upperRightY]';
  }
}
lib/src/afm/font_metrics.dart
code
Dart
// lib/src/afm/font_metrics.dart

import '../util/bounding_box.dart';
import 'char_metric.dart';
import 'composite.dart';
import 'kern_pair.dart';
import 'track_kern.dart';

/// Represents the outermost AFM type.
class FontMetrics {
  double afmVersion = 0;
  String? fontName;
  String? fullName;
  String? familyName;
  String? weight;
  BoundingBox? fontBBox;
  String? notice;
  String? encodingScheme;

  // ... outros campos do FontMetrics.java ...

  final List<CharMetric> charMetrics = [];
  final Map<String, CharMetric> _charMetricsMap = {};
  final List<KernPair> kernPairs = [];
  final List<Composite> composites = [];
  final List<TrackKern> trackKerns = [];

  void addCharMetric(CharMetric metric) {
    charMetrics.add(metric);
    if (metric.name != null) {
      _charMetricsMap[metric.name!] = metric;
    }
  }

  double getCharacterWidth(String name) {
    final metric = _charMetricsMap[name];
    return metric?.wx ?? 0.0;
  }

  // TODO: Implementar o resto dos métodos e campos
}
lib/src/afm/char_metric.dart
code
Dart
// lib/src/afm/char_metric.dart

import '../util/bounding_box.dart';
import 'ligature.dart';

/// Represents a single character metric.
class CharMetric {
  int characterCode = -1;
  String? name;
  double wx = 0;
  double wy = 0;
  BoundingBox? boundingBox;
  final List<Ligature> ligatures = [];

  // ... outros campos ...

  void addLigature(Ligature ligature) {
    ligatures.add(ligature);
  }

  // TODO: Implementar o resto dos campos
}
lib/src/afm/afm_parser.dart
code
Dart
// lib/src/afm/afm_parser.dart

import 'dart:typed_data';
import 'dart:convert';
import 'font_metrics.dart';
import 'char_metric.dart';
import '../util/bounding_box.dart';

/// This class is used to parse AFM(Adobe Font Metrics) documents.
class AFMParser {
  // Constantes
  static const String startFontMetrics = 'StartFontMetrics';
  static const String endFontMetrics = 'EndFontMetrics';
  static const String fontName = 'FontName';
  static const String fullName = 'FullName';
  static const String familyName = 'FamilyName';
  static const String weight = 'Weight';
  static const String fontBbox = 'FontBBox';
  static const String startCharMetrics = 'StartCharMetrics';
  static const String endCharMetrics = 'EndCharMetrics';
  // ... adicione todas as outras constantes

  final String _content;
  late final List<String> _lines;
  int _lineIndex = 0;

  AFMParser(Uint8List input) : _content = utf8.decode(input, allowMalformed: true) {
    _lines = _content.split(RegExp(r'\r\n?|\n'));
  }

  /// This will parse the AFM document.
  FontMetrics parse({bool reducedDataset = false}) {
    final fontMetrics = FontMetrics();

    // Encontra o início
    _findLine(startFontMetrics);

    // Lê a versão
    final versionLine = _lines[_lineIndex - 1];
    fontMetrics.afmVersion = double.parse(versionLine.split(' ').last);

    // Loop de parsing
    while (_lineIndex < _lines.length) {
      final line = _lines[_lineIndex++].trim();
      if (line.isEmpty || line.startsWith('Comment')) {
        continue;
      }

      if (line.startsWith(endFontMetrics)) {
        break;
      }

      final parts = line.split(RegExp(r'\s+'));
      final key = parts[0];
      final value = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      
      _parseLine(key, value, fontMetrics);
    }

    return fontMetrics;
  }
  
  void _parseLine(String key, String value, FontMetrics fontMetrics) {
    switch (key) {
      case fontName:
        fontMetrics.fontName = value;
        break;
      case fullName:
        fontMetrics.fullName = value;
        break;
      case familyName:
        fontMetrics.familyName = value;
        break;
      case weight:
        fontMetrics.weight = value;
        break;
      case fontBbox:
        final coords = value.split(' ').map(double.parse).toList();
        fontMetrics.fontBBox = BoundingBox.fromValues(coords[0], coords[1], coords[2], coords[3]);
        break;
      case startCharMetrics:
        _parseCharMetrics(int.parse(value), fontMetrics);
        break;
      // TODO: Implementar todos os outros casos
      default:
        // Chave desconhecida, ignorar por enquanto
        break;
    }
  }

  void _parseCharMetrics(int count, FontMetrics fontMetrics) {
    for (int i = 0; i < count; i++) {
        final line = _lines[_lineIndex++].trim();
        final charMetric = CharMetric();
        
        final parts = line.split(';').map((p) => p.trim()).toList();
        for (final part in parts) {
            if (part.isEmpty) continue;
            
            final kv = part.split(RegExp(r'\s+'));
            final key = kv[0];
            final values = kv.sublist(1);
            
            // Exemplo de parsing
            if (key == 'C') {
                charMetric.characterCode = int.parse(values[0]);
            } else if (key == 'WX') {
                charMetric.wx = double.parse(values[0]);
            } else if (key == 'N') {
                charMetric.name = values[0];
            } else if (key == 'B') {
                final coords = values.map(double.parse).toList();
                charMetric.boundingBox = BoundingBox.fromValues(coords[0], coords[1], coords[2], coords[3]);
            }
            // TODO: Implementar todos os campos de CharMetric
        }
        fontMetrics.addCharMetric(charMetric);
    }
  }

  void _findLine(String target) {
    while (_lineIndex < _lines.length) {
      if (_lines[_lineIndex].startsWith(target)) {
        _lineIndex++;
        return;
      }
      _lineIndex++;
    }
    throw Exception('"$target" not found in AFM file');
  }
}
lib/pdfbox_dart.dart
code
Dart
// lib/pdfbox_dart.dart

// Exporta as classes públicas para que possam ser usadas fora do pacote.
export 'src/afm/afm_parser.dart';
export 'src/afm/font_metrics.dart';
export 'src/afm/char_metric.dart';
export 'src/util/bounding_box.dart';
// ... outros exports ...
Próximos Passos
Complete a Fase 1 e 2: Preencha as classes de modelo de dados do AFM (Ligature, KernPair, etc.) e complete o AFMParser. Use os testes unitários do AFMParserTest.java como guia para garantir que seu parser está correto.
Aborde o CFF e TTF: Siga o roteiro, criando os esqueletos para as tabelas CFF e TTF. O CFFParser e o TTFParser serão os mais desafiadores devido à manipulação binária.
Implemente a Leitura de Dados Binários: Crie uma classe auxiliar (ex: DataReader) que encapsule um ByteData e um offset para simular o TTFDataStream. Adicione métodos como readUint16(), readInt32(), read32Fixed(), readTag(), etc.
Este esqueleto deve fornecer um excelente ponto de partida. O port é um trabalho considerável, mas dividi-lo em fases o tornará muito mais gerenciável. Boa sorte
import 'dart:io';

void main() {
  // Lista de diretórios a serem escaneados
  final diretoriosParaEscanear = [
    r'C:\MyDartProjects\pdfbox_dart\lib\src\fontbox',
    r'C:\MyDartProjects\pdfbox_dart\lib\src\io',
    r'C:\MyDartProjects\pdfbox_dart\test',
   
  ];

  // Lista de diretórios/arquivos a serem ignorados (pode usar caminhos parciais)
  final diretoriosParaIgnorar = [
    r'C:\MyDartProjects\pdfbox_dart\lib\src\dependencies',
  ];

  final arquivoSaida =
      File(r'C:\MyDartProjects\pdfbox_dart\scripts\codigo_mesclado.dart.txt');

  mesclarArquivosDart(
    diretoriosParaEscanear,
    diretoriosParaIgnorar,
    arquivoSaida,
  );
}

void mesclarArquivosDart(
  List<String> diretorios,
  List<String> ignorar,
  File arquivoSaida,
) {
  // Remove arquivo de saída se existir
  if (arquivoSaida.existsSync()) {
    arquivoSaida.deleteSync();
    print('Arquivo existente removido: ${arquivoSaida.path}');
  }

  final sink = arquivoSaida.openWrite(mode: FileMode.append);
  int totalArquivos = 0;
  int arquivosIgnorados = 0;

  // Percorre cada diretório da lista
  for (final caminhoDiretorio in diretorios) {
    final dir = Directory(caminhoDiretorio);

    if (!dir.existsSync()) {
      print('⚠️  Diretório não encontrado: $caminhoDiretorio');
      continue;
    }

    print('\n📂 Escaneando: $caminhoDiretorio');

    final arquivos = dir.listSync(recursive: true);

    for (final item in arquivos) {
      if (item is File && item.path.endsWith('.dart')) {
        // Verifica se o arquivo deve ser ignorado
        if (_deveIgnorar(item.path, ignorar)) {
          arquivosIgnorados++;
          print('  ⊘ Ignorado: ${_nomeRelativo(item.path, caminhoDiretorio)}');
          continue;
        }

        try {
          final conteudo = item.readAsStringSync();
          sink.write(
              '// ════════════════════════════════════════════════════════\n');
          sink.write('// Mesclado de: ${item.path}\n');
          sink.write(
              '// ════════════════════════════════════════════════════════\n\n');
          sink.write(conteudo);
          sink.write('\n\n');

          totalArquivos++;
          print(
              '  ✓ Adicionado: ${_nomeRelativo(item.path, caminhoDiretorio)}');
        } catch (e) {
          print('  ✗ Erro ao ler: ${item.path} - $e');
        }
      }
    }
  }

  sink.close();

  print('\n' + '═' * 60);
  print('✅ Mesclagem concluída!');
  print('📊 Total de arquivos mesclados: $totalArquivos');
  print('⊘  Arquivos ignorados: $arquivosIgnorados');
  print('💾 Arquivo de saída: ${arquivoSaida.path}');
  print('═' * 60);
}

bool _deveIgnorar(String caminhoArquivo, List<String> padroes) {
  final caminhoNormalizado = caminhoArquivo.replaceAll('\\', '/').toLowerCase();

  for (final padrao in padroes) {
    final padraoNormalizado = padrao.replaceAll('\\', '/').toLowerCase();
    if (caminhoNormalizado.contains(padraoNormalizado)) {
      return true;
    }
  }

  return false;
}

String _nomeRelativo(String caminhoCompleto, String diretorioBase) {
  final base = diretorioBase.replaceAll('\\', '/');
  final caminho = caminhoCompleto.replaceAll('\\', '/');

  if (caminho.startsWith(base)) {
    return caminho.substring(base.length).replaceFirst('/', '');
  }

  return caminho;
}


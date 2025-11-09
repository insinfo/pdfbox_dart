import 'dart:io';

/// Orquestra validações básicas de layout para fontes reais.
///
/// Exemplo de uso:
/// ```
/// dart run scripts/validate_layout.dart path/to/font1.ttf path/to/font2.otf
/// ```
///
/// O script executa utilitários existentes (inspect_cmap, validate_uvs e
/// validate_pdf_signature quando disponível) e emite um relatório resumido.
Future<void> main(List<String> args) async {
  final fonts = args.where((arg) => !arg.startsWith('--')).toList();
  if (fonts.isEmpty) {
    stderr.writeln(
      'Uso: dart run scripts/validate_layout.dart <fonte> [<fonte> ...]\n'
      'Forneça caminhos para arquivos .ttf ou .otf que devem ser verificados.',
    );
    exitCode = 64;
    return;
  }

  final checks = <_CheckTask>[
    _CheckTask('inspect_cmap', <String>['scripts/inspect_cmap.dart']),
    _CheckTask('validate_uvs', <String>['scripts/validate_uvs.dart']),
    _CheckTask(
      'validate_pdf_signature',
      <String>['scripts/validate_pdf_signature.dart'],
      optional: true,
    ),
  ];

  final results = <_CheckReport>[];
  for (final fontPath in fonts) {
    final resolved = File(fontPath).absolute;
    if (!resolved.existsSync()) {
      stderr.writeln('Arquivo não encontrado: ${resolved.path}');
      results.add(
        _CheckReport(fontPath, success: false, output: 'Arquivo inexistente'),
      );
      continue;
    }

    for (final check in checks) {
      final report = await _runCheck(check, resolved.path);
      results.add(report);
    }
  }

  _printSummary(results);

  if (results.any((report) => !report.success)) {
    exitCode = 1;
  }
}

Future<_CheckReport> _runCheck(_CheckTask task, String fontPath) async {
  if (task.optional && !File(task.command.first).existsSync()) {
    return _CheckReport(
      fontPath,
      success: true,
      output: 'Script ${task.label} não encontrado; verificação ignorada.',
    );
  }

  final command = <String>['run', ...task.command, fontPath];
  final process = await Process.run('dart', command, runInShell: true);
  final output = StringBuffer()
    ..writeln('>>> dart ${command.join(' ')}')
    ..write(process.stdout)
    ..write(process.stderr);

  return _CheckReport(
    fontPath,
    success: process.exitCode == 0,
    output: output.toString().trim(),
    check: task.label,
  );
}

void _printSummary(List<_CheckReport> reports) {
  stdout.writeln('================ Validação de Layout ================');
  if (reports.isEmpty) {
    stdout.writeln('Nenhuma verificação executada.');
    return;
  }

  final grouped = <String, List<_CheckReport>>{};
  for (final report in reports) {
    grouped.putIfAbsent(report.fontPath, () => <_CheckReport>[]).add(report);
  }

  grouped.forEach((font, checks) {
    stdout.writeln('Font: $font');
    for (final report in checks) {
      final status = report.success ? 'PASS' : 'FAIL';
      final label = report.check ?? 'arquivo';
      stdout.writeln('  [$status] $label');
      if (report.output.isNotEmpty) {
        stdout.writeln('    ${report.output.replaceAll('\n', '\n    ')}');
      }
    }
    stdout.writeln('');
  });
}

class _CheckTask {
  const _CheckTask(this.label, this.command, {this.optional = false});

  final String label;
  final List<String> command;
  final bool optional;
}

class _CheckReport {
  const _CheckReport(
    this.fontPath, {
    required this.success,
    required this.output,
    this.check,
  });

  final String fontPath;
  final bool success;
  final String output;
  final String? check;
}

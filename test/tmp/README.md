# Goldens (PDF + PNG)

Esta pasta guarda **pares de referência** (golden master) para validar que o `pdfbox_dart` renderiza igual ao PDFBox (Java).

## Estrutura

- `test/tmp/pdfs/` PDFs de entrada
- `test/tmp/png/` PNGs esperados (gerados com PDFBox Java)
- `test/tmp/actual/` PNGs renderizados pelo Dart (gerados sempre pelos testes)
- `test/tmp/diff/` diffs gerados automaticamente quando houver divergência

## Gerar PDFs de fixtures (Dart)

Gera PDFs mínimos (ex.: Type3) em `test/tmp/pdfs/`:

- `dart run scripts/generate_golden_fixtures.dart`

## Gerar PNGs (PDFBox Java)

Opção A (recomendado): usar o source em `referencias/pdfbox-java` (Maven) e o comando `PDFToImage`.

- `powershell -ExecutionPolicy Bypass -File scripts/generate_goldens_pdfbox_java.ps1`

O script tenta:
1) Reusar um `pdfbox-app-*.jar` já buildado em `referencias/pdfbox-java`.
2) Se não existir, executar `mvn -DskipTests package` para buildar.

## Rodar testes de golden

- `dart test test/goldens/golden_rendering_test.dart -r expanded`

Obs: o teste faz `skip` se não encontrar o PNG esperado.

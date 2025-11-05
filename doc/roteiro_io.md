## Estado atual do módulo IO

Este documento resume o porte completo do pacote `org.apache.pdfbox.io` para Dart, cobrindo as implementações em `lib/src/io` e os testes correspondentes em `test/io`.

- **Validação:** `dart analyze` e `dart test` executados localmente sem falhas após as últimas alterações.
- **Decisão geral:** O porte privilegia código idiomático em Dart, mantendo compatibilidade com a semântica do PDFBox original. Otimizações específicas (por exemplo, mmap real) ficam para iteração futura.

## Implementações concluídas

- **Contratos básicos** (`random_access_read.dart`, `random_access_write.dart`, `random_access.dart`): definem o núcleo de leitura/escrita com suporte a `peek`, `rewind`, `readFully` e fechamento seguro.
- **Buffers em memória** (`random_access_read_buffer.dart`, `random_access_read_write_buffer.dart`): controlam chunks redimensionáveis, clonagem de views e escrita incremental com verificação de limites.
- **Streams e adaptadores** (`random_access_input_stream.dart`, `random_access_output_stream.dart`, `non_seekable_random_access_read_input_stream.dart`, `sequence_random_access_read.dart`): cobrem leitura sequencial, escrita sequencial, suporte a fontes não seekable e concatenação de múltiplos readers.
- **Acesso a arquivos** (`random_access_read_buffered_file.dart`, `random_access_read_memory_mapped_file.dart`): cache LRU por páginas com fallback síncrono; a classe "memory mapped" permanece como wrapper sobre o reader em disco, com nota para possível FFI.
- **Scratch file** (`memory_usage_setting.dart`, `scratch_file.dart`, `scratch_file_buffer.dart`): gerenciamento híbrido RAM/arquivo, reutilização de páginas e controle de limites alinhados ao comportamento Java.
- **Utilidades e exceções** (`io_utils.dart`, `exceptions.dart`, `memory_usage_setting.dart`): fechamento silencioso, criação de caches via `MemoryUsageSetting` e tipagem de erros (`IOException`, `EofException`).

## Testes portados

- Bateria em `test/io` cobre: buffers (`random_access_read_buffer_test.dart`, `random_access_read_write_buffer_test.dart`), views, streams (`random_access_input_stream_test.dart`, `random_access_output_stream_test.dart`), adaptadores (`non_seekable_random_access_read_input_stream_test.dart`, `sequence_random_access_read_test.dart`), acesso a arquivos (`random_access_read_buffered_file_test.dart`, `random_access_read_memory_mapped_file_test.dart`) e scratch (`scratch_file_buffer_test.dart`, `scratch_file_test.dart`).
- Testes reproduzem cenários do PDFBox: leituras parciais, EOF, retrocesso, cache LRU, reutilização de páginas e regressões como PDFBOX-5981.
- Utilizamos `package:test` e mocks adequados (quando necessário) para simular arquivos temporários e streams.

## Decisões de design

- **Compatibilidade vs. idiomaticidade:** preservamos assinaturas e fluxos de controle para facilitar comparação com o Java, mas adaptamos para coleções e exceções nativas de Dart.
- **Memory-mapped file:** implementado como wrapper sobre `RandomAccessReadBufferedFile`. Documentado que uma versão usando `dart:ffi` pode surgir depois.
- **Gerenciamento de recursos:** todos os readers/writers expõem `close` idempotente; `IOUtils.closeQuietly` se integra com `try/catch` idiomático.
- **Erro intencional zero:** validações fortes em `seek`, `readFully`, `write` e limites de chunk/tamanho evitam divergências silenciosas.

## Próximos passos sugeridos

1. Revisar métricas de desempenho para decidir se vale implementar mmap nativo via FFI (`RandomAccessReadMemoryMappedFile`).
2. Iniciar o porte do módulo `fontbox`, reutilizando as mesmas convenções de testes e documentação.
3. Manter o roteiro sincronizado: atualize este arquivo sempre que novas classes de I/O forem ajustadas ou quando surgirem extensões (ex.: stream cache alternativo).
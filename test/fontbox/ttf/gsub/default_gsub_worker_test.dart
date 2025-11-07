import 'package:pdfbox_dart/src/fontbox/ttf/gsub/default_gsub_worker.dart';
import 'package:test/test.dart';

void main() {
  test('DefaultGsubWorker exposes read-only glyph views', () {
    final worker = DefaultGsubWorker();
    final original = <int>[1, 2, 3];

    final result = worker.applyTransforms(original);

    expect(result, <int>[1, 2, 3]);
    expect(() => result[0] = 99, throwsUnsupportedError);
  });
}

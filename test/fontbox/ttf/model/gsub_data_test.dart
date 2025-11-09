import 'package:pdfbox_dart/src/fontbox/ttf/model/gsub_data.dart';
import 'package:test/test.dart';

void main() {
  test('noDataFound sentinel throws on access', () {
    expect(() => GsubData.noDataFound.language, throwsUnsupportedError);
    expect(() => GsubData.noDataFound.activeScriptName, throwsUnsupportedError);
    expect(() => GsubData.noDataFound.isFeatureSupported('liga'),
        throwsUnsupportedError);
    expect(
        () => GsubData.noDataFound.getFeature('liga'), throwsUnsupportedError);
    expect(() => GsubData.noDataFound.getSupportedFeatures(),
        throwsUnsupportedError);
  });
}

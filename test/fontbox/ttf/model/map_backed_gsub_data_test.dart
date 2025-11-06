import 'package:pdfbox_dart/src/fontbox/ttf/model/language.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/map_backed_gsub_data.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/model/map_backed_script_feature.dart';
import 'package:test/test.dart';

void main() {
  group('MapBackedGsubData', () {
    test('wraps feature maps and exposes lookups', () {
      final data = MapBackedGsubData(
        Language.latin,
        'latn',
        <String, Map<List<int>, List<int>>>{
          'liga': <List<int>, List<int>>{
            <int>[10, 11]: <int>[12],
          },
        },
      );

      expect(data.language, Language.latin);
      expect(data.activeScriptName, 'latn');
      expect(data.isFeatureSupported('liga'), isTrue);
      expect(data.isFeatureSupported('kern'), isFalse);

      final feature = data.getFeature('liga');
      expect(feature, isA<MapBackedScriptFeature>());
      expect(feature.name, 'liga');

      expect(() => data.getFeature('kern'), throwsUnsupportedError);
      expect(data.getSupportedFeatures(), containsAll(<String>['liga']));
    });
  });
}

import 'package:pdfbox_dart/src/pdfbox/cos/cos_array.dart';
import 'package:pdfbox_dart/src/pdfbox/cos/cos_name.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_prop_build.dart';
import 'package:pdfbox_dart/src/pdfbox/pdmodel/interactive/digitalsignature/pd_prop_build_data_dict.dart';
import 'package:test/test.dart';

void main() {
  group('PDPropBuildDataDict', () {
    test('stores build metadata attributes', () {
      final data = PDPropBuildDataDict();

      data.setName('SignerApp');
      data.setDate('2025-11-09T12:00:00Z');
      data.setVersion('1.2.3');
      data.setRevision(42);
      data.setMinimumRevision(21);
      data.setPreRelease(true);
      data.setNonEFontNoWarn(false);
      data.setTrustedMode(true);
      data.setOS('Windows');

      final dict = data.cosObject;
      expect(dict.isDirect, isTrue);
      expect(dict.getNameAsString(COSName.nameKey), 'SignerApp');
      expect(dict.getString(COSName.date), '2025-11-09T12:00:00Z');
      expect(dict.getString(COSName.get('REx')), '1.2.3');
      expect(dict.getInt(COSName.r), 42);
      expect(dict.getInt(COSName.v), 21);
      expect(dict.getBoolean(COSName.preRelease), isTrue);
      expect(dict.getBoolean(COSName.nonEFontNoWarn), isFalse);
      expect(dict.getBoolean(COSName.trustedMode), isTrue);

      final osArray = dict.getCOSArray(COSName.os);
      expect(osArray, isA<COSArray>());
      expect(osArray!.isDirect, isTrue);
      expect((osArray[0] as dynamic).name, 'Windows');
      expect(data.getOS(), 'Windows');
    });

    test('clearing optional fields removes entries', () {
      final data = PDPropBuildDataDict();

      data.setName('SignerApp');
      data.setName(null);
      data.setDate('2025-11-09');
      data.setDate(null);
      data.setVersion('2.0');
      data.setVersion(null);
      data.setRevision(1);
      data.setRevision(null);
      data.setMinimumRevision(1);
      data.setMinimumRevision(null);
      data.setOS('Linux');
      data.setOS(null);

      final dict = data.cosObject;
      expect(dict.getDictionaryObject(COSName.nameKey), isNull);
      expect(dict.getDictionaryObject(COSName.date), isNull);
      expect(dict.getDictionaryObject(COSName.get('REx')), isNull);
      expect(dict.getDictionaryObject(COSName.r), isNull);
      expect(dict.getDictionaryObject(COSName.v), isNull);
      expect(dict.getDictionaryObject(COSName.os), isNull);
    });
  });

  group('PDPropBuild', () {
    test('binds filter, pubSec and app dictionaries', () {
      final build = PDPropBuild();
      final filter = PDPropBuildDataDict()
        ..setName('FilterModule');
      final pubSec = PDPropBuildDataDict()
        ..setName('PubSecModule');
      final app = PDPropBuildDataDict()
        ..setName('Viewer');

      build.filter = filter;
      build.pubSec = pubSec;
      build.app = app;

      final dict = build.cosObject;
      expect(dict.isDirect, isTrue);
      expect(build.filter!.name, 'FilterModule');
      expect(build.pubSec!.name, 'PubSecModule');
      expect(build.app!.name, 'Viewer');

      build.filter = null;
      build.pubSec = null;
      build.app = null;

      expect(dict.getDictionaryObject(COSName.filter), isNull);
      expect(dict.getDictionaryObject(COSName.pubSec), isNull);
      expect(dict.getDictionaryObject(COSName.app), isNull);
    });
  });
}
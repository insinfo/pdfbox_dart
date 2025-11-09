import 'package:pdfbox_dart/src/fontbox/ttf/table/common/coverage_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/coverage_table_format1.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/coverage_table_format2.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/feature_list_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/feature_record.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/feature_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/lang_sys_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/lookup_list_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/lookup_sub_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/lookup_table.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/range_record.dart';
import 'package:pdfbox_dart/src/fontbox/ttf/table/common/script_table.dart';
import 'package:test/test.dart';

void main() {
  group('Coverage tables', () {
    test('format 1 binary search', () {
      final original = <int>[10, 20, 30];
      final table = CoverageTableFormat1(1, original);

      expect(table.glyphArray, orderedEquals(<int>[10, 20, 30]));
      expect(table.getCoverageIndex(10), 0);
      expect(table.getCoverageIndex(25), lessThan(0));
      expect(table.getGlyphId(2), 30);
      expect(table.getSize(), 3);

      original[0] = 99; // ensure defensive copy
      expect(table.glyphArray.first, 10);
    });

    test('format 2 expands ranges', () {
      final ranges = <RangeRecord>[
        const RangeRecord(5, 7, 0),
        const RangeRecord(10, 11, 3),
      ];
      final table = CoverageTableFormat2(2, ranges);

      expect(table.rangeRecords, orderedEquals(ranges));
      expect(table.getSize(), 5);
      expect(table.getGlyphId(0), 5);
      expect(table.getGlyphId(4), 11);
    });
  });

  group('Feature descriptors', () {
    test('feature table preserves indices', () {
      final indices = <int>[1, 2, 3];
      final table = FeatureTable(0, indices.length, indices);
      expect(table.lookupListIndices, orderedEquals(<int>[1, 2, 3]));
      indices[0] = 99;
      expect(table.lookupListIndices.first, 1);
    });

    test('feature list stores records', () {
      final feature = FeatureTable(0, 0, const <int>[]);
      final records = <FeatureRecord>[FeatureRecord('liga', feature)];
      final listTable = FeatureListTable(records.length, records);

      expect(listTable.featureCount, 1);
      expect(listTable.featureRecords.first.featureTag, 'liga');
    });
  });

  group('Language/script tables', () {
    test('lang sys table exposes indices', () {
      final indices = <int>[4, 5];
      final langSys = LangSysTable(0, -1, indices.length, indices);
      expect(langSys.featureIndices, orderedEquals(<int>[4, 5]));
      expect(langSys.featureIndexCount, 2);
    });

    test('script table wraps map', () {
      final langSys = LangSysTable(0, -1, 0, const <int>[]);
      final script =
          ScriptTable(langSys, <String, LangSysTable>{'DFLT': langSys});

      expect(script.defaultLangSysTable, same(langSys));
      expect(script.langSysTables['DFLT'], same(langSys));
    });
  });

  group('Lookup tables', () {
    test('lookup and list tables keep subtables', () {
      final coverage = CoverageTableFormat1(1, const <int>[]);
      final subTable = _TestLookupSubTable(1, coverage);
      final lookup = LookupTable(1, 0, 0, <LookupSubTable>[subTable]);
      final listTable = LookupListTable(1, <LookupTable>[lookup]);

      expect(lookup.lookupType, 1);
      expect(lookup.subTables.single, same(subTable));
      expect(listTable.lookups.single, same(lookup));
      expect(subTable.doSubstitution(123, 0), 124);
    });
  });
}

class _TestLookupSubTable extends LookupSubTable {
  _TestLookupSubTable(int substFormat, CoverageTable coverageTable)
      : super(substFormat, coverageTable);

  @override
  int doSubstitution(int glyphId, int coverageIndex) => glyphId + 1;
}

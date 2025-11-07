import 'lang_sys_table.dart';

class ScriptTable {
  ScriptTable(this.defaultLangSysTable, Map<String, LangSysTable> langSysTables)
      : langSysTables = Map<String, LangSysTable>.unmodifiable(langSysTables);

  final LangSysTable? defaultLangSysTable;
  final Map<String, LangSysTable> langSysTables;

  @override
  String toString() =>
      'ScriptTable[hasDefault=${defaultLangSysTable != null},langSysRecordsCount=${langSysTables.length}]';
}

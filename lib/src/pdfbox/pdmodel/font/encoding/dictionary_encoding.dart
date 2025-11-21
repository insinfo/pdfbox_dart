import '../../../../fontbox/encoding/encoding.dart';
import '../../../../fontbox/encoding/mac_roman_encoding.dart';
import '../../../../fontbox/encoding/win_ansi_encoding.dart';
import '../../../../fontbox/encoding/standard_encoding.dart';
import '../../../../fontbox/encoding/mac_expert_encoding.dart';
import '../../../../fontbox/encoding/symbol_encoding.dart';
import '../../../../fontbox/encoding/zapf_dingbats_encoding.dart';
import '../../../cos/cos_array.dart';
import '../../../cos/cos_dictionary.dart';
import '../../../cos/cos_name.dart';
import '../../../cos/cos_number.dart';

class DictionaryEncoding extends Encoding {
  Encoding? baseEncoding;
  final Map<int, String> differences = {};

  DictionaryEncoding(COSDictionary dictionary) {
    if (dictionary.containsKey(COSName.baseEncoding)) {
      final name = dictionary.getCOSName(COSName.baseEncoding);
      if (name != null) {
        baseEncoding = resolveEncoding(name);
      }
    }
    if (dictionary.containsKey(COSName.differences)) {
      final diffArray = dictionary.getCOSArray(COSName.differences);
      if (diffArray != null) {
        _applyDifferences(diffArray);
      }
    }
  }
  
  DictionaryEncoding.withDifferences(COSName? baseEncodingName, COSArray? differences) {
      if (baseEncodingName != null) {
          baseEncoding = resolveEncoding(baseEncodingName);
      }
      if (differences != null) {
          _applyDifferences(differences);
      }
  }

  void _applyDifferences(COSArray diffArray) {
    int code = -1;
    for (int i = 0; i < diffArray.length; i++) {
      final obj = diffArray.getObject(i);
      if (obj is COSNumber) {
        code = obj.intValue;
      } else if (obj is COSName) {
        if (code != -1) {
          addCharacterEncoding(code, obj.name);
          code++;
        }
      }
    }
  }
  
  static Encoding? resolveEncoding(COSName name) {
      if (name == COSName.winAnsiEncoding) return WinAnsiEncoding.instance;
      if (name == COSName.macRomanEncoding) return MacRomanEncoding.instance;
      if (name == COSName.standardEncoding) return StandardEncoding.instance;
      if (name == COSName.macExpertEncoding) return MacExpertEncoding.instance;
      if (name == COSName.symbolEncoding) return SymbolEncoding.instance;
      if (name == COSName.zapfDingbatsEncoding) return ZapfDingbatsEncoding.instance;
      return null;
  }

  @override
  int? getCode(String name) {
      int? code = super.getCode(name);
      if (code == null && baseEncoding != null) {
          code = baseEncoding!.getCode(name);
      }
      return code;
  }

  @override
  String getName(int code) {
      String name = super.getName(code);
      if (name == '.notdef' && baseEncoding != null) {
          name = baseEncoding!.getName(code);
      }
      return name;
  }
}

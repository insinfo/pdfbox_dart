import 'encoding.dart';

class BuiltInEncoding extends Encoding {
  BuiltInEncoding(Map<int, String> codeToName) {
    codeToName.forEach(addCharacterEncoding);
  }
}

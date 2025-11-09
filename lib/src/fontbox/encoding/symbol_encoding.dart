import '../resources/type1_encoding_data.dart';
import 'encoding.dart';

class SymbolEncoding extends Encoding {
  SymbolEncoding._() {
    kSymbolEncoding.forEach(addCharacterEncoding);
  }

  static final SymbolEncoding instance = SymbolEncoding._();
}

import '../resources/type1_encoding_data.dart';
import 'encoding.dart';

class ZapfDingbatsEncoding extends Encoding {
  ZapfDingbatsEncoding._() {
    kZapfDingbatsEncoding.forEach(addCharacterEncoding);
  }

  static final ZapfDingbatsEncoding instance = ZapfDingbatsEncoding._();
}

import 'basic_ocsp_response.dart';
import 'ocsp_response_status.dart';

class OCSPResponse {
  OCSPResponseStatus responseStatus;

  BasicOCSPResponse? basicOCSPResponse;

  OCSPResponse(this.responseStatus, {this.basicOCSPResponse});
}

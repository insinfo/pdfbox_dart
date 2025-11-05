import '../../../src/model/ocsp/BasicOCSPResponse.dart';
import '../../../src/model/ocsp/OCSPResponseStatus.dart';

class OCSPResponse {
  OCSPResponseStatus responseStatus;

  BasicOCSPResponse? basicOCSPResponse;

  OCSPResponse(this.responseStatus, {this.basicOCSPResponse});
}

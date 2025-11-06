import 'ocsp_response_data.dart';

///
///```
///   BasicOCSPResponse       ::= SEQUENCE {
///      tbsResponseData      ResponseData,
///      signatureAlgorithm   AlgorithmIdentifier,
///      signature            BIT STRING,
///      certs            [0] EXPLICIT SEQUENCE OF Certificate OPTIONAL }
///```
///
class BasicOCSPResponse {
  OCSPResponseData? responseData;

  BasicOCSPResponse({this.responseData});
}

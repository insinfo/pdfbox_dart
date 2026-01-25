import 'ocsp_cert_status_values.dart';

///
///```
///CertStatus ::= CHOICE {
///       good        [0]     IMPLICIT NULL,
///       revoked     [1]     IMPLICIT RevokedInfo,
///       unknown     [2]     IMPLICIT UnknownInfo }
///
///   RevokedInfo ::= SEQUENCE {
///       revocationTime              GeneralizedTime,
///       revocationReason    [0]     EXPLICIT CRLReason OPTIONAL }
///
///   UnknownInfo ::= NULL
///```
///
class OCSPCertStatus {
  OCSPCertStatusValues? status;
  DateTime? revocationTime;

  OCSPCertStatus({this.status, this.revocationTime});
}

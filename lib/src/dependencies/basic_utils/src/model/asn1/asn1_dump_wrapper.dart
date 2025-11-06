import 'asn1_dump_line.dart';

///
/// Wrapper object for ASN1DumpLine
///
class ASN1DumpWrapper {
  /// List of single lines of the dump
  List<ASN1DumpLine>? lines;

  ASN1DumpWrapper({this.lines});

  ///
  /// Adding multiple ASN1DumpLine at once
  ///
  void addAll(List<ASN1DumpLine> l) {
    lines ??= [];
    lines!.addAll(l);
  }

  ///
  /// Adding a ASN1DumpLine
  ///
  void add(ASN1DumpLine l) {
    lines ??= [];
    lines!.add(l);
  }
}

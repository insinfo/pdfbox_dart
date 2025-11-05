import '../../src/model/Question.dart';
import '../../src/model/RRecord.dart';

class ResolveResponse {
  int? status;

  bool? tc;

  bool? rd;

  bool? ra;

  bool? ad;

  bool? cd;

  List<Question>? question;

  List<RRecord>? answer;

  String? comment;

  ResolveResponse(
      {this.status,
      this.tc,
      this.rd,
      this.ra,
      this.ad,
      this.cd,
      this.question,
      this.answer,
      this.comment});

  /*
   * Json to ResolveResponse object
   */
  factory ResolveResponse.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();

  /*
   * ResolveResponse object to json
   */
  Map<String, dynamic> toJson() => throw UnimplementedError();
}

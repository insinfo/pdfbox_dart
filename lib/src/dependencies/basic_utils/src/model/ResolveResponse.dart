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

  ResolveResponse({
    this.status,
    this.tc,
    this.rd,
    this.ra,
    this.ad,
    this.cd,
    this.question,
    this.answer,
    this.comment,
  });

  /*
   * Json to ResolveResponse object
   */
  factory ResolveResponse.fromJson(Map<String, dynamic> json) {
    return ResolveResponse(
      status: json['Status'] as int?,
      tc: json['TC'] as bool?,
      rd: json['RD'] as bool?,
      ra: json['RA'] as bool?,
      ad: json['AD'] as bool?,
      cd: json['CD'] as bool?,
      question: (json['Question'] as List<dynamic>?)
          ?.map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
      answer: (json['Answer'] as List<dynamic>?)
          ?.map((e) => RRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      comment: json['Comment'] as String?,
    );
  }

  /*
   * ResolveResponse object to json
   */
  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('Status', status);
    writeNotNull('TC', tc);
    writeNotNull('RD', rd);
    writeNotNull('RA', ra);
    writeNotNull('AD', ad);
    writeNotNull('CD', cd);
    // Serializa a lista de objetos chamando o método toJson() de cada um
    writeNotNull('Question', question?.map((e) => e.toJson()).toList());
    writeNotNull('Answer', answer?.map((e) => e.toJson()).toList());
    writeNotNull('Comment', comment);
    
    return val;
  }
}
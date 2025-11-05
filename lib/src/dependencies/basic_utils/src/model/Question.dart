class Question {
  String name;

  int type;

  Question({required this.name, required this.type});

  /*
   * Json to Question object
   */
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      name: json['name'] as String,
      type: json['type'] as int,
    );
  }

  /*
   * Question object to json
   */
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
    };
  }
}
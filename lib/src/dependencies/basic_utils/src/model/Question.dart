class Question {
  String name;

  int type;

  Question({required this.name, required this.type});

  /*
   * Json to Question object
   */
  factory Question.fromJson(Map<String, dynamic> json) =>
      throw UnimplementedError();

  /*
   * Question object to json
   */
  Map<String, dynamic> toJson() => throw UnimplementedError();
}

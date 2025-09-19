class QuizAnswerModel {
  int? id;
  int? quizSetId;
  String? text;
  String? attachmentPath;

  QuizAnswerModel({
    this.id,
    this.quizSetId,
    this.text,
    this.attachmentPath,
  });

  factory QuizAnswerModel.fromJson(Map<String, dynamic> json) {
    return QuizAnswerModel(
      id: int.tryParse(json['id'].toString()),
      quizSetId: int.tryParse(json['quiz_set_id'].toString()),
      text: json['text'],
      attachmentPath: json['attachment_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "quiz_set_id": quizSetId,
      "text": text,
      "attachment_path": attachmentPath,
    };
  }
}

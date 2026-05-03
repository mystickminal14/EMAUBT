class QuizQuestionModel {
  final int id;
  final String? questionText;
  final String? correctAnswer;
  final String? choiceAText;
  final String? choiceBText;
  final String? choiceCText;
  final String? choiceDText;
  final String? questionType;
  final String? questionFilePath;
  final String? wordFormatting;
  final String? createdAt;
  final String? updatedAt;

  const QuizQuestionModel({
    required this.id,
    this.questionText,
    this.correctAnswer,
    this.choiceAText,
    this.choiceBText,
    this.choiceCText,
    this.choiceDText,
    this.questionType,
    this.questionFilePath,
    this.wordFormatting,
    this.createdAt,
    this.updatedAt,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: (json['id'] as num).toInt(),
      questionText: json['question_text'] as String?,
      correctAnswer: json['correct_answer'] as String?,
      choiceAText: json['choice_A_text'] as String?,
      choiceBText: json['choice_B_text'] as String?,
      choiceCText: json['choice_C_text'] as String?,
      choiceDText: json['choice_D_text'] as String?,
      questionType: json['question_type'] as String?,
      questionFilePath: json['question_file_path'] as String?,
      wordFormatting: json['word_formatting'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question_text': questionText,
    'correct_answer': correctAnswer,
    'choice_A_text': choiceAText,
    'choice_B_text': choiceBText,
    'choice_C_text': choiceCText,
    'choice_D_text': choiceDText,
    'question_type': questionType,
    'question_file_path': questionFilePath,
    'word_formatting': wordFormatting,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  QuizQuestionModel copyWith({
    int? id,
    String? questionText,
    String? correctAnswer,
    String? choiceAText,
    String? choiceBText,
    String? choiceCText,
    String? choiceDText,
    String? questionType,
    String? questionFilePath,
    String? wordFormatting,
    String? createdAt,
    String? updatedAt,
  }) {
    return QuizQuestionModel(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      choiceAText: choiceAText ?? this.choiceAText,
      choiceBText: choiceBText ?? this.choiceBText,
      choiceCText: choiceCText ?? this.choiceCText,
      choiceDText: choiceDText ?? this.choiceDText,
      questionType: questionType ?? this.questionType,
      questionFilePath: questionFilePath ?? this.questionFilePath,
      wordFormatting: wordFormatting ?? this.wordFormatting,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
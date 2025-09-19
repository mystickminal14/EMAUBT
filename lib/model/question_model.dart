import 'package:flutter/foundation.dart';

class QuestionModel {
  final int id;
  final int quizSetId;
  final String question;
  final String optionalText;
  final String questionFile;
  final String questionType;
  final Map<String, Choice> choices;
  final String correctAnswer;
  final Map<String, List<Map<String, dynamic>>> formatting;

  QuestionModel({
    required this.id,
    required this.quizSetId,
    required this.question,
    required this.optionalText,
    required this.questionFile,
    required this.questionType,
    required this.choices,
    required this.correctAnswer,
    required this.formatting,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: int.parse(json['id'].toString()),
      quizSetId: int.parse(json['quiz_set_id'].toString()),
      question: json['question'] ?? '',
      optionalText: json['optional_text'] ?? '',
      questionFile: json['question_file'] ?? '',
      questionType: json['question_type'] ?? 'Reading',
      choices: {
        'A': Choice(
          choiceText: json['choice_A_text'] ?? '',
          choiceFile: json['choice_A_file'] ?? '',
          wordFormatting: (json['choice_A_word_formatting'] as List?)
              ?.map((w) => Map<String, dynamic>.from(w))
              .toList() ??
              [],
        ),
        'B': Choice(
          choiceText: json['choice_B_text'] ?? '',
          choiceFile: json['choice_B_file'] ?? '',
          wordFormatting: (json['choice_B_word_formatting'] as List?)
              ?.map((w) => Map<String, dynamic>.from(w))
              .toList() ??
              [],
        ),
        'C': Choice(
          choiceText: json['choice_C_text'] ?? '',
          choiceFile: json['choice_C_file'] ?? '',
          wordFormatting: (json['choice_C_word_formatting'] as List?)
              ?.map((w) => Map<String, dynamic>.from(w))
              .toList() ??
              [],
        ),
        'D': Choice(
          choiceText: json['choice_D_text'] ?? '',
          choiceFile: json['choice_D_file'] ?? '',
          wordFormatting: (json['choice_D_word_formatting'] as List?)
              ?.map((w) => Map<String, dynamic>.from(w))
              .toList() ??
              [],
        ),
      },
      correctAnswer: json['correct_answer'] ?? '',
      formatting: {
        'question_word_formatting':
        (json['question_word_formatting'] as List?)
            ?.map((w) => Map<String, dynamic>.from(w))
            .toList() ??
            [],
        'optional_word_formatting':
        (json['optional_word_formatting'] as List?)
            ?.map((w) => Map<String, dynamic>.from(w))
            .toList() ??
            [],
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_set_id': quizSetId,
      'question': question,
      'optional_text': optionalText,
      'question_file': questionFile,
      'question_type': questionType,
      'choices': {
        'A': choices['A']?.toJson(),
        'B': choices['B']?.toJson(),
        'C': choices['C']?.toJson(),
        'D': choices['D']?.toJson(),
      },
      'correct_answer': correctAnswer,
      'formatting': {
        'question_word_formatting': formatting['question_word_formatting'],
        'optional_word_formatting': formatting['optional_word_formatting'],
      },
    };
  }
}

class Choice {
  final String choiceText;
  final String choiceFile;
  final List<Map<String, dynamic>> wordFormatting;

  Choice({
    required this.choiceText,
    required this.choiceFile,
    required this.wordFormatting,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      choiceText: json['choice_text'] ?? '',
      choiceFile: json['choice_file'] ?? '',
      wordFormatting: (json['word_formatting'] as List?)
          ?.map((w) => Map<String, dynamic>.from(w))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'choice_text': choiceText,
      'choice_file': choiceFile,
      'word_formatting': wordFormatting,
    };
  }
}
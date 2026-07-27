// quiz_question_model.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ─── Text Range ───────────────────────────────────────────────────────────────

/// A single formatting range specified by character-index positions.
/// Backend format: {"start": 0, "end": 5}
class TextRange {
  final int start;
  final int end;

  const TextRange({required this.start, required this.end});

  factory TextRange.fromJson(Map<String, dynamic> json) => TextRange(
    start: (json['start'] as num).toInt(),
    end: (json['end'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  @override
  bool operator ==(Object other) =>
      other is TextRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TextRange($start, $end)';
}

// ─── Word Formatting Ranges ───────────────────────────────────────────────────

/// Holds bold / underline / italic index-range lists for one text field.
///
/// Backend JSON:
/// {
///   "bold":      [{"start": 0,  "end": 5}],
///   "underline": [{"start": 10, "end": 15}],
///   "italic":    [{"start": 20, "end": 25}]
/// }
class WordFormattingRanges {
  List<TextRange> bold;
  List<TextRange> underline;
  List<TextRange> italic;

  WordFormattingRanges({
    List<TextRange>? bold,
    List<TextRange>? underline,
    List<TextRange>? italic,
  })  : bold = bold ?? [],
        underline = underline ?? [],
        italic = italic ?? [];

  bool get isEmpty => bold.isEmpty && underline.isEmpty && italic.isEmpty;

  // ── Parse from JSON string ────────────────────────────────────────────────
  factory WordFormattingRanges.fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return WordFormattingRanges();
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return WordFormattingRanges();
      return WordFormattingRanges(
        bold: _parseRanges(decoded['bold']),
        underline: _parseRanges(decoded['underline']),
        italic: _parseRanges(decoded['italic']),
      );
    } catch (_) {
      return WordFormattingRanges();
    }
  }

  static List<TextRange> _parseRanges(dynamic list) {
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => TextRange.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Serialise to JSON string ──────────────────────────────────────────────
  String? toJsonString() {
    if (isEmpty) return null;
    final map = <String, dynamic>{};
    if (bold.isNotEmpty) map['bold'] = bold.map((r) => r.toJson()).toList();
    if (underline.isNotEmpty) {
      map['underline'] = underline.map((r) => r.toJson()).toList();
    }
    if (italic.isNotEmpty) {
      map['italic'] = italic.map((r) => r.toJson()).toList();
    }
    return jsonEncode(map);
  }

  // ── Toggle helpers ────────────────────────────────────────────────────────

  static bool _hasOverlap(List<TextRange> list, TextRange range) =>
      list.any((r) => r.start == range.start && r.end == range.end);

  WordFormattingRanges toggleBold(TextRange range) {
    final newBold = List<TextRange>.from(bold);
    if (_hasOverlap(newBold, range)) {
      newBold.removeWhere((r) => r == range);
    } else {
      newBold.add(range);
    }
    return copyWith(bold: newBold);
  }

  WordFormattingRanges toggleUnderline(TextRange range) {
    final newUnderline = List<TextRange>.from(underline);
    if (_hasOverlap(newUnderline, range)) {
      newUnderline.removeWhere((r) => r == range);
    } else {
      newUnderline.add(range);
    }
    return copyWith(underline: newUnderline);
  }

  WordFormattingRanges toggleItalic(TextRange range) {
    final newItalic = List<TextRange>.from(italic);
    if (_hasOverlap(newItalic, range)) {
      newItalic.removeWhere((r) => r == range);
    } else {
      newItalic.add(range);
    }
    return copyWith(italic: newItalic);
  }

  // ── Check a character index ───────────────────────────────────────────────
  bool isBoldAt(int charIndex) =>
      bold.any((r) => charIndex >= r.start && charIndex < r.end);

  bool isUnderlineAt(int charIndex) =>
      underline.any((r) => charIndex >= r.start && charIndex < r.end);

  bool isItalicAt(int charIndex) =>
      italic.any((r) => charIndex >= r.start && charIndex < r.end);

  WordFormattingRanges copyWith({
    List<TextRange>? bold,
    List<TextRange>? underline,
    List<TextRange>? italic,
  }) =>
      WordFormattingRanges(
        bold: bold ?? List.from(this.bold),
        underline: underline ?? List.from(this.underline),
        italic: italic ?? List.from(this.italic),
      );

  WordFormattingRanges clear() => WordFormattingRanges();
}

// ─── Quiz Question Model ──────────────────────────────────────────────────────

class QuizQuestionModel {
  final int id;
  final String? questionText;
  final String? correctAnswer;

  final String? choiceAText;
  final String? choiceBText;
  final String? choiceCText;
  final String? choiceDText;

  final String? choiceAFilePath;
  final String? choiceBFilePath;
  final String? choiceCFilePath;
  final String? choiceDFilePath;

  final String? questionType;
  final String? questionFilePath;
  final String? questionWordFormatting;
  final String? optionalText;
  final String? optionalWordFormatting;
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
    this.choiceAFilePath,
    this.choiceBFilePath,
    this.choiceCFilePath,
    this.choiceDFilePath,
    this.questionType,
    this.questionFilePath,
    this.questionWordFormatting,
    this.optionalText,
    this.optionalWordFormatting,
    this.createdAt,
    this.updatedAt,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    // Helper: extract nested choice field safely
    String? _choiceText(String key) {
      final c = json[key];
      if (c is Map<String, dynamic>) return c['text'] as String?;
      return null;
    }

    String? _choiceFile(String key) {
      final c = json[key];
      if (c is Map<String, dynamic>) return c['file'] as String?;
      return null;
    }

    // Helper: word_formatting can be a Map OR an empty List — normalise to String?
    String? _formatting(String key) {
      final v = json[key];
      if (v is Map<String, dynamic> && v.isNotEmpty) return jsonEncode(v);
      return null; // empty list [] or null → no formatting
    }

    return QuizQuestionModel(
      id: (json['id'] as num).toInt(),
      questionText: json['question'] as String?,
      correctAnswer: json['correct_answer'] as String?,
      choiceAText: _choiceText('choice_A'),
      choiceBText: _choiceText('choice_B'),
      choiceCText: _choiceText('choice_C'),
      choiceDText: _choiceText('choice_D'),
      choiceAFilePath: _choiceFile('choice_A'),
      choiceBFilePath: _choiceFile('choice_B'),
      choiceCFilePath: _choiceFile('choice_C'),
      choiceDFilePath: _choiceFile('choice_D'),
      questionType: json['question_type'] as String?,
      questionFilePath: (json['question_file'] ?? json['question_file_path']) as String?,
      questionWordFormatting: _formatting('question_word_formatting'),
      optionalText: json['optional_text'] as String?,
      optionalWordFormatting: _formatting('optional_word_formatting'),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'question': questionText,
    'correct_answer': correctAnswer,
    'choice_A_text': choiceAText,
    'choice_B_text': choiceBText,
    'choice_C_text': choiceCText,
    'choice_D_text': choiceDText,
    'choice_A_file_path': choiceAFilePath,
    'choice_B_file_path': choiceBFilePath,
    'choice_C_file_path': choiceCFilePath,
    'choice_D_file_path': choiceDFilePath,
    'question_type': questionType,
    'question_file_path': questionFilePath,
    'question_word_formatting': questionWordFormatting,
    'optional_text': optionalText,
    'optional_word_formatting': optionalWordFormatting,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  WordFormattingRanges get parsedQuestionFormatting =>
      WordFormattingRanges.fromJsonString(questionWordFormatting);

  WordFormattingRanges get parsedOptionalFormatting =>
      WordFormattingRanges.fromJsonString(optionalWordFormatting);

  QuizQuestionModel copyWith({
    int? id,
    String? questionText,
    String? correctAnswer,
    String? choiceAText,
    String? choiceBText,
    String? choiceCText,
    String? choiceDText,
    String? choiceAFilePath,
    String? choiceBFilePath,
    String? choiceCFilePath,
    String? choiceDFilePath,
    String? questionType,
    String? questionFilePath,
    String? questionWordFormatting,
    String? optionalText,
    String? optionalWordFormatting,
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
      choiceAFilePath: choiceAFilePath ?? this.choiceAFilePath,
      choiceBFilePath: choiceBFilePath ?? this.choiceBFilePath,
      choiceCFilePath: choiceCFilePath ?? this.choiceCFilePath,
      choiceDFilePath: choiceDFilePath ?? this.choiceDFilePath,
      questionType: questionType ?? this.questionType,
      questionFilePath: questionFilePath ?? this.questionFilePath,
      questionWordFormatting:
      questionWordFormatting ?? this.questionWordFormatting,
      optionalText: optionalText ?? this.optionalText,
      optionalWordFormatting:
      optionalWordFormatting ?? this.optionalWordFormatting,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


class QuizChoiceInput {
  String? text;
  File? file;

  Uint8List? fileBytes;

  String? mimeType;
  String? existingFilePath; // ← ADD THIS

  String? fileName;

  bool get hasText => text != null && text!.trim().isNotEmpty;

  bool get hasFile => fileBytes != null && mimeType != null;
  bool get hasExistingFile => existingFilePath != null && existingFilePath!.isNotEmpty;

  bool get hasContent => hasText || hasFile || hasExistingFile;

  void setFile({
    required Uint8List
    bytes,
    required String mime,
    File? sourceFile,
    String? name,
  }) {
    fileBytes = bytes;
    mimeType = mime;
    file = sourceFile;
    fileName = name ?? sourceFile?.path.split('/').last ?? 'file';
  }

  void clearFile() {
    existingFilePath = null; // ← ADD THIS
    _clearFileInternal();
  }
  void _clearFileInternal() {
    // Never delete `file` from disk here — for audio/video picks it's the
    // user's original file on the device (file_picker gives us its real
    // path, not a temp copy), not an app-owned temp file.
    file = null;
    fileBytes = null;
    mimeType = null;
    fileName = null;
  }

  void clear() {
    text = null;
    existingFilePath = null; // ← ADD THIS
    _clearFileInternal();
  }


  void setTextMode(String value) {
    text = value;
    _clearFileInternal();
  }

  void setFileMode({
    required Uint8List bytes,
    required String mime,
    File? sourceFile,
    String? name,
  }) {
    text = null;
    setFile(bytes: bytes, mime: mime, sourceFile: sourceFile, name: name);
  }

  @override
  String toString() =>
      'QuizChoiceInput(text: $text, hasFile: $hasFile, mimeType: $mimeType, fileName: $fileName)';
}
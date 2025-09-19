import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ema_app/view_model/folders/quiz_detail_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';

class QuizSetDetailPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;

  const QuizSetDetailPage({
    super.key,
    required this.quizSetId,
    required this.quizSetName,
  });

  @override
  _QuizSetDetailPageState createState() => _QuizSetDetailPageState();
}

class _QuizSetDetailPageState extends State<QuizSetDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<QuizSetDetailViewModel>().fetchQuestions(widget.quizSetId);
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Processing..."),
          ],
        ),
      ),
    );
  }

  void _addQuestion() {
    TextEditingController questionController = TextEditingController();
    TextEditingController optionalTextController = TextEditingController();
    List<TextEditingController> choiceControllers =
    List.generate(4, (_) => TextEditingController());
    List<File?> choiceFiles = List.generate(4, (_) => null);
    File? questionFile;
    String selectedAnswer = 'A';
    String selectedQuestionType = 'Reading';
    Map<String, List<Map<String, dynamic>>> wordFormatting = {
      'question_word_formatting': [],
      'optional_word_formatting': [],
    };
    List<List<Map<String, dynamic>>> choiceWordFormatting =
    List.generate(4, (_) => []);
    Map<String, double> uploadProgress = {};

    _showQuestionDialog(
      "Add Question",
      questionController,
      optionalTextController,
      choiceControllers,
      correctAnswer: selectedAnswer,
      questionFile: questionFile,
      choiceFiles: choiceFiles,
      questionType: selectedQuestionType,
      wordFormatting: wordFormatting,
      choiceWordFormatting: choiceWordFormatting,
      existingQuestionFile: '',
      existingChoiceFiles: {'A': '', 'B': '', 'C': '', 'D': ''},
      uploadProgress: uploadProgress,
      onSave: (String selectedAnswer,
          File? selectedQuestionFile,
          List<File?> selectedChoiceFiles,
          String updatedQuestionType,
          Map<String, List<Map<String, dynamic>>> wordFormatting,
          List<List<Map<String, dynamic>>> choiceWordFormatting,
          Map<String, String> choiceFileNames,
          StateSetter setDialogState) async {
        if (questionController.text.isEmpty) {
          Flushbar(
            message: 'Question text cannot be empty',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ).show(context);
          return;
        }
        final questionData = {
          'quiz_set_id': widget.quizSetId,
          'question': questionController.text,
          'optional_text': optionalTextController.text,
          'question_file': selectedQuestionFile?.path ?? '',
          'question_type': updatedQuestionType,
          'choices': {
            'A': {
              'choice_text': choiceControllers[0].text,
              'choice_file': choiceFileNames['A'] ?? '',
              'word_formatting': choiceWordFormatting[0]
            },
            'B': {
              'choice_text': choiceControllers[1].text,
              'choice_file': choiceFileNames['B'] ?? '',
              'word_formatting': choiceWordFormatting[1]
            },
            'C': {
              'choice_text': choiceControllers[2].text,
              'choice_file': choiceFileNames['C'] ?? '',
              'word_formatting': choiceWordFormatting[2]
            },
            'D': {
              'choice_text': choiceControllers[3].text,
              'choice_file': choiceFileNames['D'] ?? '',
              'word_formatting': choiceWordFormatting[3]
            },
          },
          'correct_answer': selectedAnswer,
          'formatting': wordFormatting,
        };
        _showLoadingDialog(context);
        try {
          await context.read<QuizSetDetailViewModel>().addQuestion(
              context, questionData, selectedQuestionFile, selectedChoiceFiles);
        } finally {
          Navigator.of(context).pop(); // Close loading dialog
        }
      },
    );
  }

  void _editQuestion(int index) {
    final question = context.read<QuizSetDetailViewModel>().questions[index];
    TextEditingController questionController =
    TextEditingController(text: question.question);
    TextEditingController optionalTextController =
    TextEditingController(text: question.optionalText);
    List<TextEditingController> choiceControllers = List.generate(
      4,
          (i) => TextEditingController(
          text: question.choices[String.fromCharCode(65 + i)]!.choiceText),
    );
    List<File?> choiceFiles = List.generate(4, (_) => null);
    File? questionFile;
    String selectedAnswer = question.correctAnswer;
    String selectedQuestionType = question.questionType;
    Map<String, List<Map<String, dynamic>>> wordFormatting = {
      'question_word_formatting': List<Map<String, dynamic>>.from(
          question.formatting['question_word_formatting'] ?? []),
      'optional_word_formatting': List<Map<String, dynamic>>.from(
          question.formatting['optional_word_formatting'] ?? []),
    };
    List<List<Map<String, dynamic>>> choiceWordFormatting = List.generate(
      4,
          (i) => List<Map<String, dynamic>>.from(
          question.choices[String.fromCharCode(65 + i)]!.wordFormatting),
    );
    String existingQuestionFile = question.questionFile;
    Map<String, String> existingChoiceFiles = {
      'A': question.choices['A']!.choiceFile,
      'B': question.choices['B']!.choiceFile,
      'C': question.choices['C']!.choiceFile,
      'D': question.choices['D']!.choiceFile,
    };
    Map<String, double> uploadProgress = {};

    _showQuestionDialog(
      "Edit Question",
      questionController,
      optionalTextController,
      choiceControllers,
      correctAnswer: selectedAnswer,
      questionFile: questionFile,
      choiceFiles: choiceFiles,
      questionType: selectedQuestionType,
      wordFormatting: wordFormatting,
      choiceWordFormatting: choiceWordFormatting,
      existingQuestionFile: existingQuestionFile,
      existingChoiceFiles: existingChoiceFiles,
      uploadProgress: uploadProgress,
      onSave: (String selectedAnswer,
          File? selectedQuestionFile,
          List<File?> selectedChoiceFiles,
          String updatedQuestionType,
          Map<String, List<Map<String, dynamic>>> wordFormatting,
          List<List<Map<String, dynamic>>> choiceWordFormatting,
          Map<String, String> choiceFileNames,
          StateSetter setDialogState) async {
        if (questionController.text.isEmpty) {
          Flushbar(
            message: 'Question text cannot be empty',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ).show(context);
          return;
        }
        final questionData = {
          'quiz_set_id': widget.quizSetId,
          'question': questionController.text,
          'optional_text': optionalTextController.text,
          'question_file': selectedQuestionFile?.path ?? existingQuestionFile,
          'question_type': updatedQuestionType,
          'choices': {
            'A': {
              'choice_text': choiceControllers[0].text,
              'choice_file': choiceFileNames['A'] ?? '',
              'word_formatting': choiceWordFormatting[0]
            },
            'B': {
              'choice_text': choiceControllers[1].text,
              'choice_file': choiceFileNames['B'] ?? '',
              'word_formatting': choiceWordFormatting[1]
            },
            'C': {
              'choice_text': choiceControllers[2].text,
              'choice_file': choiceFileNames['C'] ?? '',
              'word_formatting': choiceWordFormatting[2]
            },
            'D': {
              'choice_text': choiceControllers[3].text,
              'choice_file': choiceFileNames['D'] ?? '',
              'word_formatting': choiceWordFormatting[3]
            },
          },
          'correct_answer': selectedAnswer,
          'formatting': wordFormatting,
        };
        _showLoadingDialog(context);
        try {
          await context.read<QuizSetDetailViewModel>().editQuestion(
              context, question.id, questionData, selectedQuestionFile, selectedChoiceFiles);
        } finally {
          Navigator.of(context).pop(); // Close loading dialog
        }
      },
    );
  }

  void _confirmDeleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Question',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: context.read<QuizSetDetailViewModel>().isSaving
                ? null
                : () async {
              _showLoadingDialog(context);
              try {
                await context.read<QuizSetDetailViewModel>().deleteQuestion(
                    context,
                    widget.quizSetId,
                    context.read<QuizSetDetailViewModel>().questions[index].id);
              } finally {
                Navigator.of(context).pop(); // Close loading dialog
                Navigator.pop(context); // Close confirmation dialog
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: context.read<QuizSetDetailViewModel>().isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _isImageFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;
    final ext = filePath.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif');
  }

  Future<void> _openFile(String filePath) async {
    if (filePath.isEmpty) return;

    _showLoadingDialog(context);
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = filePath.split('/').last;
      final localFile = File('${tempDir.path}/$fileName');
      final response = await http.get(Uri.parse('${BaseUrl.baseUrl}/$filePath'));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        final result = await OpenFile.open(localFile.path);
        if (result.type != ResultType.done) {
          Flushbar(
            message: 'Could not open file: ${result.message}',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ).show(context);
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      Flushbar(
        message: 'Error opening file: $e',
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ).show(context);
    } finally {
      Navigator.of(context).pop(); // Close loading dialog
    }
  }

  Widget _buildFormattedText(
      String text,
      List<Map<String, dynamic>> wordFormatting,
      TextStyle? baseStyle, {
        bool isQuestion = false,
        int? questionIndex,
        bool isOptionalText = false,
        bool isChoice = false,
        String? choiceLetter,
      }) {
    const int maxChoiceLength = 50;
    String displayText = text;
    bool isTruncated = false;
    if (isChoice && text.length > maxChoiceLength) {
      displayText = text.substring(0, maxChoiceLength - 3) + '...';
      isTruncated = true;
    }

    if (isQuestion && questionIndex != null) {
      final prefix = "${questionIndex + 1}. ";
      final actualText = displayText.startsWith(prefix)
          ? displayText.substring(prefix.length)
          : displayText;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index
                  ? wordFormatting[index]['bold'] ?? false
                  : false;
              final underline = wordFormatting.length > index
                  ? wordFormatting[index]['underline'] ?? false
                  : false;
              return TextSpan(
                text: '$word ',
                style: baseStyle?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  decoration: underline ? TextDecoration.underline : null,
                ),
              );
            }),
          ],
        ),
      );
    } else if (isOptionalText) {
      const prefix = "Note: ";
      final actualText = displayText.startsWith(prefix)
          ? displayText.substring(prefix.length)
          : displayText;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index
                  ? wordFormatting[index]['bold'] ?? false
                  : false;
              final underline = wordFormatting.length > index
                  ? wordFormatting[index]['underline'] ?? false
                  : false;
              return TextSpan(
                text: '$word ',
                style: baseStyle?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  decoration: underline ? TextDecoration.underline : null,
                ),
              );
            }),
          ],
        ),
      );
    } else if (isChoice && choiceLetter != null) {
      final prefix = "$choiceLetter) ";
      final actualText = displayText.startsWith(prefix)
          ? displayText.substring(prefix.length)
          : displayText;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index
                  ? wordFormatting[index]['bold'] ?? false
                  : false;
              final underline = wordFormatting.length > index
                  ? wordFormatting[index]['underline'] ?? false
                  : false;
              return TextSpan(
                text: isTruncated && index == words.length - 1 ? '...' : '$word ',
                style: baseStyle?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  decoration: underline ? TextDecoration.underline : null,
                ),
              );
            }),
          ],
        ),
      );
    } else {
      final words = displayText.split(' ').where((w) => w.isNotEmpty).toList();
      return RichText(
        text: TextSpan(
          children: words.asMap().entries.map((entry) {
            final index = entry.key;
            final word = entry.value;
            final bold = wordFormatting.length > index
                ? wordFormatting[index]['bold'] ?? false
                : false;
            final underline = wordFormatting.length > index
                ? wordFormatting[index]['underline'] ?? false
                : false;
            return TextSpan(
              text: '$word ',
              style: baseStyle?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                decoration: underline ? TextDecoration.underline : null,
              ),
            );
          }).toList(),
        ),
      );
    }
  }

  void _showQuestionDialog(
      String title,
      TextEditingController questionController,
      TextEditingController optionalTextController,
      List<TextEditingController> choiceControllers, {
        required String correctAnswer,
        required File? questionFile,
        required List<File?> choiceFiles,
        required String questionType,
        required Map<String, List<Map<String, dynamic>>> wordFormatting,
        required List<List<Map<String, dynamic>>> choiceWordFormatting,
        required String existingQuestionFile,
        required Map<String, String> existingChoiceFiles,
        required Map<String, double> uploadProgress,
        required Function(
            String,
            File?,
            List<File?>,
            String,
            Map<String, List<Map<String, dynamic>>>,
            List<List<Map<String, dynamic>>>,
            Map<String, String>,
            StateSetter,
            ) onSave,
      }) {
    String selectedAnswer = correctAnswer;
    String selectedQuestionType = questionType;
    bool isDraggingQuestion = false;
    List<bool> isDraggingChoice = List.generate(4, (_) => false);
    File? localQuestionFile = questionFile;
    List<File?> localChoiceFiles = List.from(choiceFiles);
    String localExistingQuestionFile = existingQuestionFile;
    Map<String, String> choiceFileNames = Map.from(existingChoiceFiles);

    Future<void> pickFile(Function(File) onFileSelected) async {
      FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        onFileSelected(File(result.files.single.path!));
      }
    }

    bool isChoiceImageOrAudioOnly(int index) {
      final text = choiceControllers[index].text.trim();
      final file = localChoiceFiles[index]?.path.toLowerCase() ??
          choiceFileNames[String.fromCharCode(65 + index)]?.toLowerCase() ??
          '';
      return text.isEmpty &&
          (file.endsWith('.png') ||
              file.endsWith('.jpg') ||
              file.endsWith('.jpeg') ||
              file.endsWith('.gif') ||
              file.endsWith('.mp3') ||
              file.endsWith('.wav') ||
              file.endsWith('.aac') ||
              file.endsWith('.ogg'));
    }

    void updateWordFormatting(
        String text, String key, StateSetter setDialogState) {
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      setDialogState(() {
        final currentFormatting = wordFormatting[key]!;
        wordFormatting[key] = List.generate(
          words.length,
              (i) => i < currentFormatting.length
              ? currentFormatting[i]
              : {'bold': false, 'underline': false},
        );
      });
    }

    void updateChoiceWordFormatting(int index, StateSetter setDialogState) {
      final words = choiceControllers[index]
          .text
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      setDialogState(() {
        final currentFormatting = choiceWordFormatting[index];
        choiceWordFormatting[index] = List.generate(
          words.length,
              (i) => i < currentFormatting.length
              ? currentFormatting[i]
              : {'bold': false, 'underline': false},
        );
      });
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: "Enter question",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (text) => updateWordFormatting(
                        text, 'question_word_formatting', setDialogState),
                  ),
                  const SizedBox(height: 8),
                  if (questionController.text.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: questionController.text
                          .split(' ')
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        if (word.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            Text(
                              word,
                              style: TextStyle(
                                fontWeight: wordFormatting['question_word_formatting']!
                                    .isNotEmpty &&
                                    index <
                                        wordFormatting['question_word_formatting']!
                                            .length &&
                                    wordFormatting['question_word_formatting']![index]
                                    ['bold'] ==
                                        true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: wordFormatting['question_word_formatting']!
                                    .isNotEmpty &&
                                    index <
                                        wordFormatting['question_word_formatting']!
                                            .length &&
                                    wordFormatting['question_word_formatting']![index]
                                    ['underline'] ==
                                        true
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: wordFormatting['question_word_formatting']!
                                      .isNotEmpty &&
                                      index <
                                          wordFormatting['question_word_formatting']!
                                              .length
                                      ? wordFormatting['question_word_formatting']![index]
                                  ['bold'] ??
                                      false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['question_word_formatting']!
                                          .length >
                                          index) {
                                        wordFormatting['question_word_formatting']!
                                        [index]['bold'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('B'),
                                Checkbox(
                                  value: wordFormatting['question_word_formatting']!
                                      .isNotEmpty &&
                                      index <
                                          wordFormatting['question_word_formatting']!
                                              .length
                                      ? wordFormatting['question_word_formatting']![index]
                                  ['underline'] ??
                                      false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['question_word_formatting']!
                                          .length >
                                          index) {
                                        wordFormatting['question_word_formatting']!
                                        [index]['underline'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('U'),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  DropTarget(
                    onDragEntered: (_) =>
                        setDialogState(() => isDraggingQuestion = true),
                    onDragExited: (_) =>
                        setDialogState(() => isDraggingQuestion = false),
                    onDragDone: (details) async {
                      if (details.files.isNotEmpty) {
                        try {
                          final filePath = details.files.first.path;
                          final file = File(filePath);
                          if (await file.exists()) {
                            setDialogState(() => localQuestionFile = file);
                          } else {
                            Flushbar(
                              message: 'Cannot access file: Restricted or invalid path',
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 3),
                            ).show(context);
                          }
                        } catch (e) {
                          Flushbar(
                            message: 'Error accessing file: $e',
                            backgroundColor: Colors.redAccent,
                            duration: const Duration(seconds: 3),
                          ).show(context);
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDraggingQuestion ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: isDraggingQuestion
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => pickFile(
                                          (file) => setDialogState(() => localQuestionFile = file)),
                                  child: Text(localQuestionFile == null &&
                                      localExistingQuestionFile.isEmpty
                                      ? "Attach Question File"
                                      : "Change Question File"),
                                ),
                              ),
                              if (uploadProgress.containsKey('question'))
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 100,
                                    child: LinearProgressIndicator(
                                      value: uploadProgress['question'],
                                      minHeight: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (localQuestionFile != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text("File: ${localQuestionFile!.path.split('/').last}"),
                            ),
                          if (localQuestionFile == null && localExistingQuestionFile.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Text("File: ${localExistingQuestionFile.split('/').last}"),
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () =>
                                        setDialogState(() => localExistingQuestionFile = ''),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionalTextController,
                    decoration: const InputDecoration(
                      labelText: "Optional Text (Inside Box)",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (text) => updateWordFormatting(
                        text, 'optional_word_formatting', setDialogState),
                  ),
                  const SizedBox(height: 8),
                  if (optionalTextController.text.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: optionalTextController.text
                          .split(' ')
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        if (word.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            Text(
                              word,
                              style: TextStyle(
                                fontWeight: wordFormatting['optional_word_formatting']!
                                    .isNotEmpty &&
                                    index <
                                        wordFormatting['optional_word_formatting']!.length &&
                                    wordFormatting['optional_word_formatting']![index]
                                    ['bold'] ==
                                        true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: wordFormatting['optional_word_formatting']!
                                    .isNotEmpty &&
                                    index <
                                        wordFormatting['optional_word_formatting']!.length &&
                                    wordFormatting['optional_word_formatting']![index]
                                    ['underline'] ==
                                        true
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: wordFormatting['optional_word_formatting']!
                                      .isNotEmpty &&
                                      index <
                                          wordFormatting['optional_word_formatting']!.length
                                      ? wordFormatting['optional_word_formatting']![index]
                                  ['bold'] ??
                                      false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['optional_word_formatting']!
                                          .length >
                                          index) {
                                        wordFormatting['optional_word_formatting']![index]
                                        ['bold'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('B'),
                                Checkbox(
                                  value: wordFormatting['optional_word_formatting']!
                                      .isNotEmpty &&
                                      index <
                                          wordFormatting['optional_word_formatting']!.length
                                      ? wordFormatting['optional_word_formatting']![index]
                                  ['underline'] ??
                                      false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['optional_word_formatting']!
                                          .length >
                                          index) {
                                        wordFormatting['optional_word_formatting']![index]
                                        ['underline'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('U'),
                              ],
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < 4; i++)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: choiceControllers[i],
                          decoration: InputDecoration(
                            labelText: "Choice ${String.fromCharCode(65 + i)}",
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => updateChoiceWordFormatting(i, setDialogState),
                        ),
                        const SizedBox(height: 8),
                        if (choiceControllers[i].text.isNotEmpty &&
                            !isChoiceImageOrAudioOnly(i))
                          Wrap(
                            spacing: 8,
                            children: choiceControllers[i].text.split(' ').asMap().entries.map((entry) {
                              final index = entry.key;
                              final word = entry.value;
                              if (word.isEmpty) return const SizedBox.shrink();
                              return Column(
                                children: [
                                  Text(
                                    word,
                                    style: TextStyle(
                                      fontWeight: choiceWordFormatting[i].isNotEmpty &&
                                          index < choiceWordFormatting[i].length &&
                                          choiceWordFormatting[i][index]['bold'] == true
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      decoration: choiceWordFormatting[i].isNotEmpty &&
                                          index < choiceWordFormatting[i].length &&
                                          choiceWordFormatting[i][index]['underline'] ==
                                              true
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: choiceWordFormatting[i].isNotEmpty &&
                                            index < choiceWordFormatting[i].length
                                            ? choiceWordFormatting[i][index]['bold'] ?? false
                                            : false,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (choiceWordFormatting[i].length > index) {
                                              choiceWordFormatting[i][index]['bold'] = value!;
                                            }
                                          });
                                        },
                                      ),
                                      const Text('B'),
                                      Checkbox(
                                        value: choiceWordFormatting[i].isNotEmpty &&
                                            index < choiceWordFormatting[i].length
                                            ? choiceWordFormatting[i][index]['underline'] ??
                                            false
                                            : false,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (choiceWordFormatting[i].length > index) {
                                              choiceWordFormatting[i][index]['underline'] =
                                              value!;
                                            }
                                          });
                                        },
                                      ),
                                      const Text('U'),
                                    ],
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        DropTarget(
                          onDragEntered: (_) => setDialogState(() => isDraggingChoice[i] = true),
                          onDragExited: (_) => setDialogState(() => isDraggingChoice[i] = false),
                          onDragDone: (details) async {
                            if (details.files.isNotEmpty) {
                              try {
                                final filePath = details.files.first.path;
                                final file = File(filePath);
                                if (await file.exists()) {
                                  setDialogState(() {
                                    localChoiceFiles[i] = file;
                                    choiceFileNames[String.fromCharCode(65 + i)] =
                                        file.path.split('/').last;
                                  });
                                } else {
                                  Flushbar(
                                    message: 'Cannot access file: Restricted or invalid path',
                                    backgroundColor: Colors.redAccent,
                                    duration: const Duration(seconds: 3),
                                  ).show(context);
                                }
                              } catch (e) {
                                Flushbar(
                                  message: 'Error accessing file: $e',
                                  backgroundColor: Colors.redAccent,
                                  duration: const Duration(seconds: 3),
                                ).show(context);
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: isDraggingChoice[i] ? Colors.blue : Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: isDraggingChoice[i]
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.transparent,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => pickFile((file) => setDialogState(() {
                                          localChoiceFiles[i] = file;
                                          choiceFileNames[String.fromCharCode(65 + i)] =
                                              file.path.split('/').last;
                                        })),
                                        child: Text(
                                            localChoiceFiles[i] == null &&
                                                choiceFileNames[String.fromCharCode(65 + i)]!
                                                    .isEmpty
                                                ? "Attach File"
                                                : "Change File"),
                                      ),
                                    ),
                                    if (uploadProgress.containsKey('choice_$i'))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: SizedBox(
                                          width: 100,
                                          child: LinearProgressIndicator(
                                            value: uploadProgress['choice_$i'],
                                            minHeight: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (localChoiceFiles[i] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child:
                                    Text("File: ${localChoiceFiles[i]!.path.split('/').last}"),
                                  ),
                                if (localChoiceFiles[i] == null &&
                                    choiceFileNames[String.fromCharCode(65 + i)]!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                            "File: ${choiceFileNames[String.fromCharCode(65 + i)]!.split('/').last}"),
                                        IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setDialogState(() {
                                            choiceFileNames[String.fromCharCode(65 + i)] = '';
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  DropdownButton<String>(
                    value: selectedAnswer,
                    onChanged: (String? newValue) =>
                        setDialogState(() => selectedAnswer = newValue!),
                    items: ['A', 'B', 'C', 'D']
                        .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text("Correct Answer: $value"),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedQuestionType,
                    onChanged: (String? newValue) =>
                        setDialogState(() => selectedQuestionType = newValue!),
                    items: ['Reading', 'Listening']
                        .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text("Question Type: $value"),
                    ))
                        .toList(),
                  ),
                  if (context.read<QuizSetDetailViewModel>().isSaving)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(
                        value: context.read<QuizSetDetailViewModel>().saveProgress / 100,
                        minHeight: 10,
                      ),
                    ),
                  if (context.read<QuizSetDetailViewModel>().isSaving)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          'Saving: ${context.read<QuizSetDetailViewModel>().saveProgress.toStringAsFixed(0)}%'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: context.read<QuizSetDetailViewModel>().isSaving
                  ? null
                  : () async {
                await onSave(
                  selectedAnswer,
                  localQuestionFile,
                  localChoiceFiles,
                  selectedQuestionType,
                  wordFormatting,
                  choiceWordFormatting,
                  choiceFileNames,
                  setDialogState,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: context.read<QuizSetDetailViewModel>().isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quizSetName),
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: context.read<QuizSetDetailViewModel>().isSaving ? null : _addQuestion,
              tooltip: 'Add Question',
            ),
          ],
        ),
        body: Consumer<QuizSetDetailViewModel>(
          builder: (_, vm, __) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.questions.isEmpty) {
              return const Center(
                child: Text(
                  "No questions available.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.questions.length,
                  itemBuilder: (context, index) {
                    final question = vm.questions[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFormattedText(
                              "${index + 1}. ${question.question}",
                              question.formatting['question_word_formatting'] ?? [],
                              Theme.of(context).textTheme.titleLarge,
                              isQuestion: true,
                              questionIndex: index,
                            ),
                            if (question.questionType.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Type: ${question.questionType}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            if (question.questionFile.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  _isImageFile(question.questionFile)
                                      ? Image.network(
                                    '${BaseUrl.baseUrl}/${question.questionFile}',
                                    height: 150,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(
                                        height: 150,
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) =>
                                    const Text('Image not available'),
                                  )
                                      : ElevatedButton(
                                    onPressed: () => _openFile(question.questionFile),
                                    child: Text(
                                        "Open File: ${question.questionFile.split('/').last}"),
                                  ),
                                ],
                              ),
                            if (question.optionalText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildFormattedText(
                                  "Note: ${question.optionalText}",
                                  question.formatting['optional_word_formatting'] ?? [],
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                  isOptionalText: true,
                                ),
                              ),
                            const SizedBox(height: 16),
                            for (var choice in ['A', 'B', 'C', 'D'])
                              if (question.choices[choice] != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildFormattedText(
                                              "$choice) ${question.choices[choice]!.choiceText}",
                                              question.choices[choice]!.wordFormatting,
                                              Theme.of(context).textTheme.bodyLarge,
                                              isChoice: true,
                                              choiceLetter: choice,
                                            ),
                                          ),
                                          if (question.choices[choice]!.choiceFile.isNotEmpty)
                                            Flexible(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 16),
                                                child: Text(
                                                  "File: ${question.choices[choice]!.choiceFile.split('/').last}",
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (question.choices[choice]!.choiceFile.isNotEmpty)
                                        _isImageFile(question.choices[choice]!.choiceFile)
                                            ? Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Image.network(
                                            '${BaseUrl.baseUrl}/${question.choices[choice]!.choiceFile}',
                                            height: 150,
                                            fit: BoxFit.contain,
                                            loadingBuilder:
                                                (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const SizedBox(
                                                height: 150,
                                                child: Center(
                                                    child: CircularProgressIndicator()),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                            const Text('Image not available'),
                                          ),
                                        )
                                            : Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: ElevatedButton(
                                            onPressed: () => _openFile(
                                                question.choices[choice]!.choiceFile),
                                            child: const Text("Open File"),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 16),
                            if (question.correctAnswer.isNotEmpty)
                              Text(
                                "Correct Answer: ${question.correctAnswer}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: vm.isSaving ? null : () => _editQuestion(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: vm.isSaving
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                        : const Text("Edit"),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: vm.isSaving
                                        ? null
                                        : () => _confirmDeleteQuestion(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: vm.isSaving
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                        : const Text("Delete"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
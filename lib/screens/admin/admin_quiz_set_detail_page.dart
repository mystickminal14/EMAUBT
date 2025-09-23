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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizSetDetailViewModel>().fetchQuestions(widget.quizSetId);
    });
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              "Processing...",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
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
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
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
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
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
              context,
              question.id,
              questionData,
              selectedQuestionFile,
              selectedChoiceFiles);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Question',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: context.read<QuizSetDetailViewModel>().isSaving
                ? null
                : () async {
              _showLoadingDialog(context);
              try {
                await context
                    .read<QuizSetDetailViewModel>()
                    .deleteQuestion(
                    context,
                    widget.quizSetId,
                    context
                        .read<QuizSetDetailViewModel>()
                        .questions[index]
                        .id);
              } finally {
                Navigator.of(context).pop(); // Close loading dialog
                Navigator.pop(context); // Close confirmation dialog
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: context.read<QuizSetDetailViewModel>().isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Text('Delete', style: TextStyle(fontSize: 14)),
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
      final response =
      await http.get(Uri.parse('${BaseUrl.baseUrl}/$filePath'));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        final result = await OpenFile.open(localFile.path);
        if (result.type != ResultType.done) {
          Flushbar(
            message: 'Could not open file: ${result.message}',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(8),
            borderRadius: BorderRadius.circular(8),
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
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
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
                text:
                isTruncated && index == words.length - 1 ? '...' : '$word ',
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
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Question Section
                      Text(
                        "Question",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: questionController,
                        decoration: InputDecoration(
                          labelText: "Enter question",
                          hintText: "Type your question here...",
                          prefixIcon: const Icon(Icons.question_mark, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 2,
                        onChanged: (text) => updateWordFormatting(
                            text, 'question_word_formatting', setDialogState),
                      ),
                      const SizedBox(height: 12),
                      // Question Word Formatting
                      if (questionController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Format Question Text",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: questionController.text
                                  .split(' ')
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final word = entry.value;
                                if (word.isEmpty) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        word,
                                        style: TextStyle(
                                          fontWeight: wordFormatting[
                                          'question_word_formatting']!
                                              .isNotEmpty &&
                                              index <
                                                  wordFormatting[
                                                  'question_word_formatting']!
                                                      .length &&
                                              wordFormatting[
                                              'question_word_formatting']![
                                              index]['bold'] ==
                                                  true
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          decoration: wordFormatting[
                                          'question_word_formatting']!
                                              .isNotEmpty &&
                                              index <
                                                  wordFormatting[
                                                  'question_word_formatting']!
                                                      .length &&
                                              wordFormatting[
                                              'question_word_formatting']![
                                              index]['underline'] ==
                                                  true
                                              ? TextDecoration.underline
                                              : null,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: "Bold",
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.format_bold,
                                                size: 20,
                                                color: wordFormatting[
                                                'question_word_formatting']!
                                                    .isNotEmpty &&
                                                    index <
                                                        wordFormatting[
                                                        'question_word_formatting']!
                                                            .length &&
                                                    wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['bold'] ==
                                                        true
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  if (wordFormatting[
                                                  'question_word_formatting']!
                                                      .length >
                                                      index) {
                                                    wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['bold'] =
                                                    !(wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['bold'] ??
                                                        false);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          Tooltip(
                                            message: "Underline",
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.format_underline,
                                                size: 20,
                                                color: wordFormatting[
                                                'question_word_formatting']!
                                                    .isNotEmpty &&
                                                    index <
                                                        wordFormatting[
                                                        'question_word_formatting']!
                                                            .length &&
                                                    wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['underline'] ==
                                                        true
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  if (wordFormatting[
                                                  'question_word_formatting']!
                                                      .length >
                                                      index) {
                                                    wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['underline'] =
                                                    !(wordFormatting[
                                                    'question_word_formatting']![
                                                    index]['underline'] ??
                                                        false);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Question File Upload
                      Text(
                        "Question File",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                  message:
                                  'Cannot access file: Restricted or invalid path',
                                  backgroundColor: Colors.redAccent,
                                  duration: const Duration(seconds: 3),
                                  margin: const EdgeInsets.all(8),
                                  borderRadius: BorderRadius.circular(8),
                                ).show(context);
                              }
                            } catch (e) {
                              Flushbar(
                                message: 'Error accessing file: $e',
                                backgroundColor: Colors.redAccent,
                                duration: const Duration(seconds: 3),
                                margin: const EdgeInsets.all(8),
                                borderRadius: BorderRadius.circular(8),
                              ).show(context);
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDraggingQuestion
                                  ? Colors.blueAccent
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isDraggingQuestion
                                ? Colors.blueAccent.withOpacity(0.1)
                                : Colors.grey[50],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => pickFile((file) =>
                                          setDialogState(
                                                  () => localQuestionFile = file)),
                                      icon: const Icon(Icons.attach_file,
                                          size: 20),
                                      label: Text(
                                        localQuestionFile == null &&
                                            localExistingQuestionFile.isEmpty
                                            ? "Attach Question File"
                                            : "Change Question File",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blueAccent,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (uploadProgress.containsKey('question'))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: CircularProgressIndicator(
                                        value: uploadProgress['question'],
                                        strokeWidth: 3,
                                      ),
                                    ),
                                ],
                              ),
                              if (localQuestionFile != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "File: ${localQuestionFile!.path.split('/').last}",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () => setDialogState(
                                                () => localQuestionFile = null),
                                      ),
                                    ],
                                  ),
                                ),
                              if (localQuestionFile == null &&
                                  localExistingQuestionFile.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "File: ${localExistingQuestionFile.split('/').last}",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () => setDialogState(
                                                () => localExistingQuestionFile = ''),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      // Optional Text Section
                      Text(
                        "Optional Text",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: optionalTextController,
                        decoration: InputDecoration(
                          labelText: "Optional Text (Inside Box)",
                          hintText: "Add optional text here...",
                          prefixIcon: const Icon(Icons.note, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 2,
                        onChanged: (text) => updateWordFormatting(
                            text, 'optional_word_formatting', setDialogState),
                      ),
                      const SizedBox(height: 12),
                      // Optional Text Formatting
                      if (optionalTextController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Format Optional Text",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: optionalTextController.text
                                  .split(' ')
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                final index = entry.key;
                                final word = entry.value;
                                if (word.isEmpty) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        word,
                                        style: TextStyle(
                                          fontWeight: wordFormatting[
                                          'optional_word_formatting']!
                                              .isNotEmpty &&
                                              index <
                                                  wordFormatting[
                                                  'optional_word_formatting']!
                                                      .length &&
                                              wordFormatting[
                                              'optional_word_formatting']![
                                              index]['bold'] ==
                                                  true
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          decoration: wordFormatting[
                                          'optional_word_formatting']!
                                              .isNotEmpty &&
                                              index <
                                                  wordFormatting[
                                                  'optional_word_formatting']!
                                                      .length &&
                                              wordFormatting[
                                              'optional_word_formatting']![
                                              index]['underline'] ==
                                                  true
                                              ? TextDecoration.underline
                                              : null,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: "Bold",
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.format_bold,
                                                size: 20,
                                                color: wordFormatting[
                                                'optional_word_formatting']!
                                                    .isNotEmpty &&
                                                    index <
                                                        wordFormatting[
                                                        'optional_word_formatting']!
                                                            .length &&
                                                    wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['bold'] ==
                                                        true
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  if (wordFormatting[
                                                  'optional_word_formatting']!
                                                      .length >
                                                      index) {
                                                    wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['bold'] =
                                                    !(wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['bold'] ??
                                                        false);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          Tooltip(
                                            message: "Underline",
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.format_underline,
                                                size: 20,
                                                color: wordFormatting[
                                                'optional_word_formatting']!
                                                    .isNotEmpty &&
                                                    index <
                                                        wordFormatting[
                                                        'optional_word_formatting']!
                                                            .length &&
                                                    wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['underline'] ==
                                                        true
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                              ),
                                              onPressed: () {
                                                setDialogState(() {
                                                  if (wordFormatting[
                                                  'optional_word_formatting']!
                                                      .length >
                                                      index) {
                                                    wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['underline'] =
                                                    !(wordFormatting[
                                                    'optional_word_formatting']![
                                                    index]['underline'] ??
                                                        false);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const Divider(height: 32),
                      // Choices Section
                      Text(
                        "Choices",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < 4; i++)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: choiceControllers[i],
                              decoration: InputDecoration(
                                labelText: "Choice ${String.fromCharCode(65 + i)}",
                                hintText: "Enter choice text...",
                                prefixIcon: const Icon(Icons.radio_button_unchecked,
                                    size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              onChanged: (_) =>
                                  updateChoiceWordFormatting(i, setDialogState),
                            ),
                            const SizedBox(height: 12),
                            if (choiceControllers[i].text.isNotEmpty &&
                                !isChoiceImageOrAudioOnly(i))
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Format Choice ${String.fromCharCode(65 + i)}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: choiceControllers[i]
                                        .text
                                        .split(' ')
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final word = entry.value;
                                      if (word.isEmpty)
                                        return const SizedBox.shrink();
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              word,
                                              style: TextStyle(
                                                fontWeight: choiceWordFormatting[i]
                                                    .isNotEmpty &&
                                                    index <
                                                        choiceWordFormatting[i]
                                                            .length &&
                                                    choiceWordFormatting[i][index]
                                                    ['bold'] ==
                                                        true
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                decoration: choiceWordFormatting[i]
                                                    .isNotEmpty &&
                                                    index <
                                                        choiceWordFormatting[i]
                                                            .length &&
                                                    choiceWordFormatting[i][index]
                                                    ['underline'] ==
                                                        true
                                                    ? TextDecoration.underline
                                                    : null,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Tooltip(
                                                  message: "Bold",
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.format_bold,
                                                      size: 20,
                                                      color: choiceWordFormatting[
                                                      i]
                                                          .isNotEmpty &&
                                                          index <
                                                              choiceWordFormatting[
                                                              i]
                                                                  .length &&
                                                          choiceWordFormatting[i]
                                                          [index]['bold'] ==
                                                              true
                                                          ? Colors.blueAccent
                                                          : Colors.grey,
                                                    ),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        if (choiceWordFormatting[i]
                                                            .length >
                                                            index) {
                                                          choiceWordFormatting[i]
                                                          [index]['bold'] =
                                                          !(choiceWordFormatting[i]
                                                          [index]['bold'] ??
                                                              false);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                                Tooltip(
                                                  message: "Underline",
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.format_underline,
                                                      size: 20,
                                                      color: choiceWordFormatting[
                                                      i]
                                                          .isNotEmpty &&
                                                          index <
                                                              choiceWordFormatting[
                                                              i]
                                                                  .length &&
                                                          choiceWordFormatting[i][
                                                          index]
                                                          ['underline'] ==
                                                              true
                                                          ? Colors.blueAccent
                                                          : Colors.grey,
                                                    ),
                                                    onPressed: () {
                                                      setDialogState(() {
                                                        if (choiceWordFormatting[i]
                                                            .length >
                                                            index) {
                                                          choiceWordFormatting[i][
                                                          index]['underline'] =
                                                          !(choiceWordFormatting[i]
                                                          [index]['underline'] ??
                                                              false);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            DropTarget(
                              onDragEntered: (_) =>
                                  setDialogState(() => isDraggingChoice[i] = true),
                              onDragExited: (_) => setDialogState(
                                      () => isDraggingChoice[i] = false),
                              onDragDone: (details) async {
                                if (details.files.isNotEmpty) {
                                  try {
                                    final filePath = details.files.first.path;
                                    final file = File(filePath);
                                    if (await file.exists()) {
                                      setDialogState(() {
                                        localChoiceFiles[i] = file;
                                        choiceFileNames[
                                        String.fromCharCode(65 + i)] =
                                            file.path.split('/').last;
                                      });
                                    } else {
                                      Flushbar(
                                        message:
                                        'Cannot access file: Restricted or invalid path',
                                        backgroundColor: Colors.redAccent,
                                        duration: const Duration(seconds: 3),
                                        margin: const EdgeInsets.all(8),
                                        borderRadius: BorderRadius.circular(8),
                                      ).show(context);
                                    }
                                  } catch (e) {
                                    Flushbar(
                                      message: 'Error accessing file: $e',
                                      backgroundColor: Colors.redAccent,
                                      duration: const Duration(seconds: 3),
                                      margin: const EdgeInsets.all(8),
                                      borderRadius: BorderRadius.circular(8),
                                    ).show(context);
                                  }
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isDraggingChoice[i]
                                        ? Colors.blueAccent
                                        : Colors.grey[300]!,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDraggingChoice[i]
                                      ? Colors.blueAccent.withOpacity(0.1)
                                      : Colors.grey[50],
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => pickFile(
                                                    (file) => setDialogState(() {
                                                  localChoiceFiles[i] = file;
                                                  choiceFileNames[String.fromCharCode(
                                                      65 + i)] =
                                                      file.path
                                                          .split('/')
                                                          .last;
                                                })),
                                            icon: const Icon(Icons.attach_file,
                                                size: 20),
                                            label: Text(
                                              localChoiceFiles[i] == null &&
                                                  choiceFileNames[
                                                  String.fromCharCode(
                                                      65 + i)]!
                                                      .isEmpty
                                                  ? "Attach File"
                                                  : "Change File",
                                              style:
                                              const TextStyle(fontSize: 14),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.blueAccent,
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (uploadProgress
                                            .containsKey('choice_$i'))
                                          Padding(
                                            padding:
                                            const EdgeInsets.only(left: 12),
                                            child: CircularProgressIndicator(
                                              value: uploadProgress['choice_$i'],
                                              strokeWidth: 3,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (localChoiceFiles[i] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "File: ${localChoiceFiles[i]!.path.split('/').last}",
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon:
                                              const Icon(Icons.clear, size: 20),
                                              onPressed: () => setDialogState(
                                                      () => localChoiceFiles[i] = null),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (localChoiceFiles[i] == null &&
                                        choiceFileNames[
                                        String.fromCharCode(65 + i)]!
                                            .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "File: ${choiceFileNames[String.fromCharCode(65 + i)]!.split('/').last}",
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon:
                                              const Icon(Icons.clear, size: 20),
                                              onPressed: () => setDialogState(() {
                                                choiceFileNames[
                                                String.fromCharCode(
                                                    65 + i)] = '';
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
                      const Divider(height: 32),
                      // Correct Answer and Question Type
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedAnswer,
                              decoration: InputDecoration(
                                labelText: "Correct Answer",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: ['A', 'B', 'C', 'D']
                                  .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text("Answer $value"),
                              ))
                                  .toList(),
                              onChanged: (String? newValue) =>
                                  setDialogState(() => selectedAnswer = newValue!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedQuestionType,
                              decoration: InputDecoration(
                                labelText: "Question Type",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: ['Reading', 'Listening']
                                  .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                                  .toList(),
                              onChanged: (String? newValue) => setDialogState(
                                      () => selectedQuestionType = newValue!),
                            ),
                          ),
                        ],
                      ),
                      if (context.read<QuizSetDetailViewModel>().isSaving)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: context
                                    .read<QuizSetDetailViewModel>()
                                    .saveProgress /
                                    100,
                                minHeight: 6,
                                backgroundColor: Colors.grey[200],
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Saving: ${context.read<QuizSetDetailViewModel>().saveProgress.toStringAsFixed(0)}%',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              elevation: 4,
                            ),
                            child: context.read<QuizSetDetailViewModel>().isSaving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : const Text(
                              'Save',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
              onPressed: context.read<QuizSetDetailViewModel>().isSaving
                  ? null
                  : _addQuestion,
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
              return Center(
                child: Text(
                  "No questions available.",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.grey, fontSize: 16),
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
                              question.formatting['question_word_formatting'] ??
                                  [],
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
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
                                    color: Colors.blueAccent,
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
                                    loadingBuilder: (context, child,
                                        loadingProgress) {
                                      if (loadingProgress == null)
                                        return child;
                                      return const SizedBox(
                                        height: 150,
                                        child: Center(
                                            child:
                                            CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (context, error,
                                        stackTrace) =>
                                    const Text('Image not available'),
                                  )
                                      : ElevatedButton.icon(
                                    onPressed: () =>
                                        _openFile(question.questionFile),
                                    icon: const Icon(Icons.file_open,
                                        size: 20),
                                    label: Text(
                                      "Open File: ${question.questionFile.split('/').last}",
                                      style:
                                      const TextStyle(fontSize: 14),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (question.optionalText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildFormattedText(
                                  "Note: ${question.optionalText}",
                                  question.formatting[
                                  'optional_word_formatting'] ??
                                      [],
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                  isOptionalText: true,
                                ),
                              ),
                            const SizedBox(height: 16),
                            for (var choice in ['A', 'B', 'C', 'D'])
                              if (question.choices[choice] != null)
                                Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildFormattedText(
                                              "$choice) ${question.choices[choice]!.choiceText}",
                                              question.choices[choice]!
                                                  .wordFormatting,
                                              Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                              isChoice: true,
                                              choiceLetter: choice,
                                            ),
                                          ),
                                          if (question.choices[choice]!
                                              .choiceFile.isNotEmpty)
                                            Flexible(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 16),
                                                child: Text(
                                                  "File: ${question.choices[choice]!.choiceFile.split('/').last}",
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                      color:
                                                      Colors.grey[600]),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (question.choices[choice]!.choiceFile
                                          .isNotEmpty)
                                        _isImageFile(question
                                            .choices[choice]!.choiceFile)
                                            ? Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8),
                                          child: Image.network(
                                            '${BaseUrl.baseUrl}/${question.choices[choice]!.choiceFile}',
                                            height: 150,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context,
                                                child, loadingProgress) {
                                              if (loadingProgress == null)
                                                return child;
                                              return const SizedBox(
                                                height: 150,
                                                child: Center(
                                                    child:
                                                    CircularProgressIndicator()),
                                              );
                                            },
                                            errorBuilder: (context, error,
                                                stackTrace) =>
                                            const Text(
                                                'Image not available'),
                                          ),
                                        )
                                            : Padding(
                                          padding: const EdgeInsets.only(
                                              top: 8),
                                          child: ElevatedButton.icon(
                                            onPressed: () => _openFile(
                                                question.choices[choice]!
                                                    .choiceFile),
                                            icon: const Icon(
                                                Icons.file_open,
                                                size: 20),
                                            label:
                                            const Text("Open File"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor:
                                              Colors.blueAccent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(8),
                                              ),
                                            ),
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
                                    onPressed: vm.isSaving
                                        ? null
                                        : () => _editQuestion(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: vm.isSaving
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                        : const Text(
                                      "Edit",
                                      style: TextStyle(fontSize: 14),
                                    ),
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
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: vm.isSaving
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                        : const Text(
                                      "Delete",
                                      style: TextStyle(fontSize: 14),
                                    ),
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

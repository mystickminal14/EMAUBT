import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ema_app/view_model/folders/quiz_detail_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:ema_app/constants/base_url.dart';

// ─── Reusing FolderTheme palette inline (or import folder_theme.dart) ────────
class _QTheme {
  static const Color primary  = Color(0xFF1A1A2E);
  static const Color accent   = Color(0xFF4F8EF7);
  static const Color surface  = Color(0xFFF5F7FF);
  static const Color card     = Colors.white;
  static const Color border   = Color(0xFFE3E8F0);
  static const Color textMain = Color(0xFF1A1A2E);
  static const Color textSub  = Color(0xFF6B7A99);
  static const Color iconBg   = Color(0xFFEEF4FF);
  static const Color iconBgAccent = Color(0xFFDBEAFF);
  static const Color success  = Color(0xFF2ECC71);
  static const Color danger   = Color(0xFFE74C3C);

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: primary.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static BoxDecoration get fieldDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border),
  );

  static BoxDecoration get dropZoneDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border),
  );

  static BoxDecoration dropZoneDragging() => BoxDecoration(
    color: accent.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: accent, width: 1.5),
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textMain,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSub,
    letterSpacing: 0.4,
  );

  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: textMain,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    color: textSub,
    height: 1.5,
  );

  static InputDecoration inputDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSub, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: textSub)
            : null,
        filled: true,
        fillColor: surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      );
}

// ─── Main Page ────────────────────────────────────────────────────────────────
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

  // ── Loading dialog ─────────────────────────────────────────────────────────
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _QTheme.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: _QTheme.accent,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Processing…',
                style: TextStyle(
                  color: _QTheme.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
          _showFlushbar('Could not open file: ${result.message}');
        }
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      _showFlushbar('Error opening file: $e');
    } finally {
      Navigator.of(context).pop();
    }
  }

  void _showFlushbar(String msg) {
    Flushbar(
      message: msg,
      backgroundColor: _QTheme.danger,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
    ).show(context);
  }

  // ── Formatted text ─────────────────────────────────────────────────────────
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

    String prefix = '';
    String actualText = displayText;

    if (isQuestion && questionIndex != null) {
      prefix = '${questionIndex + 1}. ';
      if (displayText.startsWith(prefix)) {
        actualText = displayText.substring(prefix.length);
      }
    } else if (isOptionalText) {
      prefix = 'Note: ';
      if (displayText.startsWith(prefix)) {
        actualText = displayText.substring(prefix.length);
      }
    } else if (isChoice && choiceLetter != null) {
      prefix = '$choiceLetter) ';
      if (displayText.startsWith(prefix)) {
        actualText = displayText.substring(prefix.length);
      }
    }

    final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

    return RichText(
      text: TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix, style: baseStyle),
          ...words.asMap().entries.map((entry) {
            final i = entry.key;
            final word = entry.value;
            final bold = wordFormatting.length > i
                ? wordFormatting[i]['bold'] ?? false
                : false;
            final underline = wordFormatting.length > i
                ? wordFormatting[i]['underline'] ?? false
                : false;
            return TextSpan(
              text: isTruncated && i == words.length - 1 ? '...' : '$word ',
              style: baseStyle?.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                decoration: underline ? TextDecoration.underline : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Add / Edit wrappers ────────────────────────────────────────────────────
  void _addQuestion() {
    final questionCtrl = TextEditingController();
    final optCtrl = TextEditingController();
    final choiceCtrls = List.generate(4, (_) => TextEditingController());
    final choiceFiles = List<File?>.filled(4, null, growable: false);
    final wordFormatting = {
      'question_word_formatting': <Map<String, dynamic>>[],
      'optional_word_formatting': <Map<String, dynamic>>[],
    };
    final choiceWordFormatting =
    List.generate(4, (_) => <Map<String, dynamic>>[]);
    final Map<String, double> uploadProgress = {};

    _showQuestionDialog(
      'Add Question',
      questionCtrl,
      optCtrl,
      choiceCtrls,
      correctAnswer: 'A',
      questionFile: null,
      choiceFiles: choiceFiles,
      questionType: 'Reading',
      wordFormatting: wordFormatting,
      choiceWordFormatting: choiceWordFormatting,
      existingQuestionFile: '',
      existingChoiceFiles: {'A': '', 'B': '', 'C': '', 'D': ''},
      uploadProgress: uploadProgress,
      onSave: (selectedAnswer, selQFile, selCFiles, updQType, wf, cwf,
          choiceFileNames, setDs) async {
        if (questionCtrl.text.isEmpty) {
          _showFlushbar('Question text cannot be empty');
          return;
        }
        final data = _buildQuestionData(
          questionCtrl, optCtrl, choiceCtrls,
          selQFile, '', choiceFileNames,
          updQType, selectedAnswer, wf, cwf,
        );
        _showLoadingDialog(context);
        try {
          await context
              .read<QuizSetDetailViewModel>()
              .addQuestion(context, data, selQFile, selCFiles);
        } finally {
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _editQuestion(int index) {
    final question =
    context.read<QuizSetDetailViewModel>().questions[index];
    final questionCtrl = TextEditingController(text: question.question);
    final optCtrl = TextEditingController(text: question.optionalText);
    final choiceCtrls = List.generate(
      4,
          (i) => TextEditingController(
          text: question.choices[String.fromCharCode(65 + i)]!.choiceText),
    );
    final choiceFiles = List<File?>.filled(4, null, growable: false);
    final wordFormatting = {
      'question_word_formatting': List<Map<String, dynamic>>.from(
          question.formatting['question_word_formatting'] ?? []),
      'optional_word_formatting': List<Map<String, dynamic>>.from(
          question.formatting['optional_word_formatting'] ?? []),
    };
    final choiceWordFormatting = List.generate(
      4,
          (i) => List<Map<String, dynamic>>.from(
          question.choices[String.fromCharCode(65 + i)]!.wordFormatting),
    );
    final existingChoiceFiles = {
      'A': question.choices['A']!.choiceFile,
      'B': question.choices['B']!.choiceFile,
      'C': question.choices['C']!.choiceFile,
      'D': question.choices['D']!.choiceFile,
    };
    final Map<String, double> uploadProgress = {};

    _showQuestionDialog(
      'Edit Question',
      questionCtrl,
      optCtrl,
      choiceCtrls,
      correctAnswer: question.correctAnswer,
      questionFile: null,
      choiceFiles: choiceFiles,
      questionType: question.questionType,
      wordFormatting: wordFormatting,
      choiceWordFormatting: choiceWordFormatting,
      existingQuestionFile: question.questionFile,
      existingChoiceFiles: existingChoiceFiles,
      uploadProgress: uploadProgress,
      onSave: (selectedAnswer, selQFile, selCFiles, updQType, wf, cwf,
          choiceFileNames, setDs) async {
        if (questionCtrl.text.isEmpty) {
          _showFlushbar('Question text cannot be empty');
          return;
        }
        final data = _buildQuestionData(
          questionCtrl, optCtrl, choiceCtrls,
          selQFile, question.questionFile, choiceFileNames,
          updQType, selectedAnswer, wf, cwf,
        );
        _showLoadingDialog(context);
        try {
          await context.read<QuizSetDetailViewModel>().editQuestion(
              context, question.id, data, selQFile, selCFiles);
        } finally {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Map<String, dynamic> _buildQuestionData(
      TextEditingController questionCtrl,
      TextEditingController optCtrl,
      List<TextEditingController> choiceCtrls,
      File? qFile,
      String existingQFile,
      Map<String, String> choiceFileNames,
      String qType,
      String answer,
      Map<String, List<Map<String, dynamic>>> wf,
      List<List<Map<String, dynamic>>> cwf,
      ) {
    return {
      'quiz_set_id': widget.quizSetId,
      'question': questionCtrl.text,
      'optional_text': optCtrl.text,
      'question_file': qFile?.path ?? existingQFile,
      'question_type': qType,
      'choices': {
        for (int i = 0; i < 4; i++)
          String.fromCharCode(65 + i): {
            'choice_text': choiceCtrls[i].text,
            'choice_file': choiceFileNames[String.fromCharCode(65 + i)] ?? '',
            'word_formatting': cwf[i],
          }
      },
      'correct_answer': answer,
      'formatting': wf,
    };
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _QTheme.card,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon header
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _QTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _QTheme.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Question',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _QTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This question will be permanently removed and cannot be undone.',
                style: TextStyle(
                  fontSize: 13,
                  color: _QTheme.textSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _QTheme.textSub,
                        side: const BorderSide(color: _QTheme.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        _showLoadingDialog(context);
                        final vm = context.read<QuizSetDetailViewModel>();
                        try {
                          await vm.deleteQuestion(context, widget.quizSetId,
                              vm.questions[index].id);
                        } finally {
                          Navigator.of(context).pop();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _QTheme.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Question dialog ────────────────────────────────────────────────────────
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

    Future<void> pickFile(Function(File) onSelected) async {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        onSelected(File(result.files.single.path!));
      }
    }

    void updateWordFormatting(
        String text, String key, StateSetter setDs) {
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      setDs(() {
        final cur = wordFormatting[key]!;
        wordFormatting[key] = List.generate(
          words.length,
              (i) => i < cur.length ? cur[i] : {'bold': false, 'underline': false},
        );
      });
    }

    void updateChoiceWordFormatting(int index, StateSetter setDs) {
      final words = choiceControllers[index]
          .text
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      setDs(() {
        final cur = choiceWordFormatting[index];
        choiceWordFormatting[index] = List.generate(
          words.length,
              (i) => i < cur.length ? cur[i] : {'bold': false, 'underline': false},
        );
      });
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints:
            const BoxConstraints(maxWidth: 620, maxHeight: 780),
            decoration: BoxDecoration(
              color: _QTheme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _QTheme.primary.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Dialog header ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: _QTheme.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                    border: const Border(
                        bottom: BorderSide(color: _QTheme.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _QTheme.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.quiz_rounded,
                            color: _QTheme.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _QTheme.textMain,
                            letterSpacing: -0.3,
                          )),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded,
                            color: _QTheme.textSub, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: _QTheme.border.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable body ─────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Question text
                        _dialogSectionLabel('Question'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: questionController,
                          decoration: _QTheme.inputDecoration(
                              'Enter your question…',
                              icon: Icons.help_outline_rounded),
                          maxLines: 3,
                          style: const TextStyle(
                              color: _QTheme.textMain, fontSize: 14),
                          onChanged: (t) => updateWordFormatting(
                              t, 'question_word_formatting', setDs),
                        ),

                        // Word formatting chips
                        if (questionController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _WordFormattingRow(
                            text: questionController.text,
                            formatting: wordFormatting['question_word_formatting']!,
                            setDs: setDs,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Question file
                        _dialogSectionLabel('Question File'),
                        const SizedBox(height: 8),
                        _DropZone(
                          isDragging: isDraggingQuestion,
                          localFile: localQuestionFile,
                          existingFile: localExistingQuestionFile,
                          onDragEnter: () =>
                              setDs(() => isDraggingQuestion = true),
                          onDragExit: () =>
                              setDs(() => isDraggingQuestion = false),
                          onDrop: (file) =>
                              setDs(() => localQuestionFile = file),
                          onPick: () => pickFile(
                                  (f) => setDs(() => localQuestionFile = f)),
                          onClearLocal: () =>
                              setDs(() => localQuestionFile = null),
                          onClearExisting: () =>
                              setDs(() => localExistingQuestionFile = ''),
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: _QTheme.border),
                        const SizedBox(height: 20),

                        // Optional text
                        _dialogSectionLabel('Optional Text (Note Box)'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: optionalTextController,
                          decoration: _QTheme.inputDecoration(
                              'Add supporting note…',
                              icon: Icons.sticky_note_2_outlined),
                          maxLines: 2,
                          style: const TextStyle(
                              color: _QTheme.textMain, fontSize: 14),
                          onChanged: (t) => updateWordFormatting(
                              t, 'optional_word_formatting', setDs),
                        ),

                        if (optionalTextController.text.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _WordFormattingRow(
                            text: optionalTextController.text,
                            formatting:
                            wordFormatting['optional_word_formatting']!,
                            setDs: setDs,
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(color: _QTheme.border),
                        const SizedBox(height: 20),

                        // Choices
                        _dialogSectionLabel('Answer Choices'),
                        const SizedBox(height: 12),

                        for (int i = 0; i < 4; i++) ...[
                          _ChoiceLabel(letter: String.fromCharCode(65 + i)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: choiceControllers[i],
                            decoration: _QTheme.inputDecoration(
                                'Choice ${String.fromCharCode(65 + i)} text…'),
                            style: const TextStyle(
                                color: _QTheme.textMain, fontSize: 14),
                            onChanged: (_) =>
                                updateChoiceWordFormatting(i, setDs),
                          ),
                          if (choiceControllers[i].text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _WordFormattingRow(
                              text: choiceControllers[i].text,
                              formatting: choiceWordFormatting[i],
                              setDs: setDs,
                            ),
                          ],
                          const SizedBox(height: 10),
                          _DropZone(
                            isDragging: isDraggingChoice[i],
                            localFile: localChoiceFiles[i],
                            existingFile:
                            choiceFileNames[String.fromCharCode(65 + i)]!,
                            onDragEnter: () =>
                                setDs(() => isDraggingChoice[i] = true),
                            onDragExit: () =>
                                setDs(() => isDraggingChoice[i] = false),
                            onDrop: (file) => setDs(() {
                              localChoiceFiles[i] = file;
                              choiceFileNames[String.fromCharCode(65 + i)] =
                                  file.path.split('/').last;
                            }),
                            onPick: () => pickFile((f) => setDs(() {
                              localChoiceFiles[i] = f;
                              choiceFileNames[String.fromCharCode(65 + i)] =
                                  f.path.split('/').last;
                            })),
                            onClearLocal: () =>
                                setDs(() => localChoiceFiles[i] = null),
                            onClearExisting: () => setDs(() =>
                            choiceFileNames[
                            String.fromCharCode(65 + i)] = ''),
                          ),
                          const SizedBox(height: 20),
                        ],

                        const Divider(color: _QTheme.border),
                        const SizedBox(height: 20),

                        // Correct answer + type row
                        Row(
                          children: [
                            Expanded(
                              child: _StyledDropdown<String>(
                                label: 'Correct Answer',
                                value: selectedAnswer,
                                items: ['A', 'B', 'C', 'D'],
                                itemLabel: (v) => 'Answer $v',
                                onChanged: (v) =>
                                    setDs(() => selectedAnswer = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StyledDropdown<String>(
                                label: 'Question Type',
                                value: selectedQuestionType,
                                items: ['Reading', 'Listening'],
                                itemLabel: (v) => v,
                                onChanged: (v) =>
                                    setDs(() => selectedQuestionType = v!),
                              ),
                            ),
                          ],
                        ),

                        // Save progress
                        if (context
                            .read<QuizSetDetailViewModel>()
                            .isSaving) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: context
                                  .read<QuizSetDetailViewModel>()
                                  .saveProgress /
                                  100,
                              minHeight: 6,
                              backgroundColor: _QTheme.border,
                              color: _QTheme.accent,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // ── Footer actions ──────────────────────────────────────────
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: _QTheme.surface,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                    border: const Border(
                        top: BorderSide(color: _QTheme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _QTheme.textSub,
                          side: const BorderSide(color: _QTheme.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: context
                            .read<QuizSetDetailViewModel>()
                            .isSaving
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
                            setDs,
                          );
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _QTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _QTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _QuizDetailHeader(quizSetName: widget.quizSetName),
            // Body
            Expanded(
              child: Consumer<QuizSetDetailViewModel>(
                builder: (_, vm, __) {
                  if (vm.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: _QTheme.accent, strokeWidth: 2.5),
                    );
                  }
                  if (vm.questions.isEmpty) {
                    return _QuizEmptyState(onAdd: _addQuestion);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: vm.questions.length,
                    itemBuilder: (_, index) {
                      final question = vm.questions[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                            milliseconds: 250 + (index.clamp(0, 10) * 30)),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, child) =>
                            Opacity(opacity: v, child: child),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: _QTheme.cardDecoration,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question header row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Index badge
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _QTheme.accent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: _QTheme.accent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _buildFormattedText(
                                            question.question,
                                            question.formatting[
                                            'question_word_formatting'] ??
                                                [],
                                            const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: _QTheme.textMain,
                                              height: 1.4,
                                            ),
                                          ),
                                          if (question.questionType.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _TypeBadge(
                                                type: question.questionType),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Menu
                                    _QuestionCardMenu(
                                      onEdit: () => _editQuestion(index),
                                      onDelete: () => _confirmDelete(index),
                                    ),
                                  ],
                                ),

                                // Question file
                                if (question.questionFile.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _FilePreview(
                                    filePath: question.questionFile,
                                    isImage: _isImageFile(question.questionFile),
                                    onOpen: () =>
                                        _openFile(question.questionFile),
                                  ),
                                ],

                                // Optional text
                                if (question.optionalText.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _QTheme.iconBg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: _QTheme.iconBgAccent),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.info_outline_rounded,
                                            size: 15,
                                            color: _QTheme.accent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildFormattedText(
                                            question.optionalText,
                                            question.formatting[
                                            'optional_word_formatting'] ??
                                                [],
                                            const TextStyle(
                                              fontSize: 13,
                                              color: _QTheme.textSub,
                                              height: 1.5,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),
                                const Divider(color: _QTheme.border, height: 1),
                                const SizedBox(height: 14),

                                // Choices grid
                                for (var choice in ['A', 'B', 'C', 'D'])
                                  if (question.choices[choice] != null)
                                    _ChoiceRow(
                                      letter: choice,
                                      choiceText: question
                                          .choices[choice]!.choiceText,
                                      choiceFile: question
                                          .choices[choice]!.choiceFile,
                                      wordFormatting: question
                                          .choices[choice]!.wordFormatting,
                                      isCorrect: question.correctAnswer == choice,
                                      isImage: _isImageFile(
                                          question.choices[choice]!.choiceFile),
                                      onOpenFile: () => _openFile(
                                          question.choices[choice]!.choiceFile),
                                      buildFormatted: _buildFormattedText,
                                    ),

                                const SizedBox(height: 12),

                                // Correct answer badge
                                if (question.correctAnswer.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _QTheme.success.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: _QTheme.success
                                              .withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            size: 15,
                                            color: _QTheme.success),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Correct: ${question.correctAnswer}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _QTheme.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addQuestion,
        backgroundColor: _QTheme.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Question',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

Widget _dialogSectionLabel(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: _QTheme.textSub,
    letterSpacing: 0.8,
  ),
);

class _QuizDetailHeader extends StatelessWidget {
  final String quizSetName;
  const _QuizDetailHeader({required this.quizSetName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _QTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _QTheme.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _QTheme.textMain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizSetName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _QTheme.textMain,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Consumer<QuizSetDetailViewModel>(
                  builder: (_, vm, __) => Text(
                    '${vm.questions.length} question${vm.questions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 13, color: _QTheme.textSub),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isListening = type.toLowerCase() == 'listening';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
        isListening ? const Color(0xFFE8F5FF) : const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening
                ? Icons.headphones_rounded
                : Icons.menu_book_rounded,
            size: 11,
            color: _QTheme.accent,
          ),
          const SizedBox(width: 4),
          Text(
            type,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _QTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _QuestionCardMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: _QTheme.textSub, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 17, color: _QTheme.accent),
            SizedBox(width: 10),
            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded,
                size: 17, color: _QTheme.danger),
            SizedBox(width: 10),
            Text('Delete',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: _QTheme.danger)),
          ]),
        ),
      ],
    );
  }
}

class _ChoiceLabel extends StatelessWidget {
  final String letter;
  const _ChoiceLabel({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _QTheme.iconBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _QTheme.iconBgAccent),
          ),
          child: Text(letter,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _QTheme.accent)),
        ),
        const SizedBox(width: 8),
        Text('Choice $letter', style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _QTheme.textSub,
        )),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String letter;
  final String choiceText;
  final String choiceFile;
  final List<Map<String, dynamic>> wordFormatting;
  final bool isCorrect;
  final bool isImage;
  final VoidCallback onOpenFile;
  final Widget Function(
      String,
      List<Map<String, dynamic>>,
      TextStyle?, {
      bool isChoice,
      String? choiceLetter,
      }) buildFormatted;

  const _ChoiceRow({
    required this.letter,
    required this.choiceText,
    required this.choiceFile,
    required this.wordFormatting,
    required this.isCorrect,
    required this.isImage,
    required this.onOpenFile,
    required this.buildFormatted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? _QTheme.success.withOpacity(0.06)
            : _QTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect
              ? _QTheme.success.withOpacity(0.3)
              : _QTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrect
                  ? _QTheme.success.withOpacity(0.15)
                  : _QTheme.iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCorrect ? _QTheme.success : _QTheme.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (choiceText.isNotEmpty)
                  buildFormatted(
                    choiceText,
                    wordFormatting,
                    TextStyle(
                      fontSize: 14,
                      color: _QTheme.textMain,
                      fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                    ),
                    isChoice: true,
                    choiceLetter: letter,
                  ),
                if (choiceFile.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  isImage
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '${BaseUrl.baseUrl}/$choiceFile',
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Text('Image unavailable',
                          style: TextStyle(
                              color: _QTheme.textSub, fontSize: 12)),
                    ),
                  )
                      : GestureDetector(
                    onTap: onOpenFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _QTheme.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _QTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attach_file_rounded,
                              size: 14, color: _QTheme.accent),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              choiceFile.split('/').last,
                              style: const TextStyle(
                                  fontSize: 12, color: _QTheme.accent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 2),
              child: Icon(Icons.check_circle_rounded,
                  size: 16, color: _QTheme.success),
            ),
        ],
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final String filePath;
  final bool isImage;
  final VoidCallback onOpen;
  const _FilePreview(
      {required this.filePath, required this.isImage, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          '${BaseUrl.baseUrl}/$filePath',
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Text('Image not available',
              style: TextStyle(color: _QTheme.textSub)),
        ),
      );
    }
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _QTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _QTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 18, color: _QTheme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filePath.split('/').last,
                style: const TextStyle(
                    fontSize: 13, color: _QTheme.textMain),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 15, color: _QTheme.textSub),
          ],
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final bool isDragging;
  final File? localFile;
  final String existingFile;
  final VoidCallback onDragEnter;
  final VoidCallback onDragExit;
  final Function(File) onDrop;
  final VoidCallback onPick;
  final VoidCallback onClearLocal;
  final VoidCallback onClearExisting;

  const _DropZone({
    required this.isDragging,
    required this.localFile,
    required this.existingFile,
    required this.onDragEnter,
    required this.onDragExit,
    required this.onDrop,
    required this.onPick,
    required this.onClearLocal,
    required this.onClearExisting,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = localFile != null || existingFile.isNotEmpty;
    return DropTarget(
      onDragEntered: (_) => onDragEnter(),
      onDragExited: (_) => onDragExit(),
      onDragDone: (details) async {
        if (details.files.isNotEmpty) {
          final file = File(details.files.first.path);
          if (await file.exists()) onDrop(file);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: isDragging
            ? _QTheme.dropZoneDragging()
            : _QTheme.dropZoneDecoration,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onPick,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _QTheme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _QTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file_rounded,
                              size: 16, color: _QTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            hasFile ? 'Change file' : 'Attach file',
                            style: const TextStyle(
                                fontSize: 13,
                                color: _QTheme.accent,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (!hasFile)
                            const Text('or drag & drop',
                                style: TextStyle(
                                    fontSize: 12, color: _QTheme.textSub)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (localFile != null)
              _fileChip(localFile!.path.split('/').last, onClearLocal),
            if (localFile == null && existingFile.isNotEmpty)
              _fileChip(existingFile.split('/').last, onClearExisting),
          ],
        ),
      ),
    );
  }

  Widget _fileChip(String name, VoidCallback onClear) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: _QTheme.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 12, color: _QTheme.textSub),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded,
                size: 16, color: _QTheme.textSub),
          ),
        ],
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: _QTheme.inputDecoration(label),
      style: const TextStyle(color: _QTheme.textMain, fontSize: 14),
      dropdownColor: _QTheme.card,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: _QTheme.textSub),
      items: items
          .map((v) => DropdownMenuItem(
        value: v,
        child: Text(itemLabel(v)),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _WordFormattingRow extends StatelessWidget {
  final String text;
  final List<Map<String, dynamic>> formatting;
  final StateSetter setDs;

  const _WordFormattingRow({
    required this.text,
    required this.formatting,
    required this.setDs,
  });

  @override
  Widget build(BuildContext context) {
    final words =
    text.split(' ').asMap().entries.where((e) => e.value.isNotEmpty);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: words.map((entry) {
        final i = entry.key;
        final word = entry.value;
        final isBold = formatting.length > i
            ? formatting[i]['bold'] == true
            : false;
        final isUnderline = formatting.length > i
            ? formatting[i]['underline'] == true
            : false;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: BoxDecoration(
            color: _QTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _QTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word,
                style: TextStyle(
                  fontSize: 12,
                  color: _QTheme.textMain,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  decoration:
                  isUnderline ? TextDecoration.underline : null,
                ),
              ),
              const SizedBox(width: 4),
              _FormatIconBtn(
                icon: Icons.format_bold_rounded,
                active: isBold,
                onTap: () {
                  setDs(() {
                    if (formatting.length > i) {
                      formatting[i]['bold'] = !isBold;
                    }
                  });
                },
              ),
              _FormatIconBtn(
                icon: Icons.format_underline_rounded,
                active: isUnderline,
                onTap: () {
                  setDs(() {
                    if (formatting.length > i) {
                      formatting[i]['underline'] = !isUnderline;
                    }
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FormatIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FormatIconBtn(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: active ? _QTheme.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon,
            size: 15,
            color: active ? _QTheme.accent : _QTheme.textSub),
      ),
    );
  }
}

class _QuizEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _QuizEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _QTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.quiz_outlined,
                size: 38, color: _QTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No questions yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _QTheme.textMain)),
          const SizedBox(height: 6),
          const Text('Tap the button below to add your first question.',
              style: TextStyle(fontSize: 13, color: _QTheme.textSub)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Question',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _QTheme.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

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
  List<Map<String, dynamic>> questions = [];
  static const String baseUrl = 'https://theemaeducation.com';
  bool isSaving = false;
  double saveProgress = 0.0;

 Future<void> fetchQuestions() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/quiz_set_detail_page.php?quiz_set_id=${widget.quizSetId}'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 30), onTimeout: () {
      throw TimeoutException('Request timed out after 30 seconds');
    });

    debugPrint('Fetch response: ${response.statusCode}');
    debugPrint('Fetch body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['questions'] != null && data['questions'] is List) {
        setState(() {
          questions = List<Map<String, dynamic>>.from(data['questions']).map((q) {
            return {
              'id': q['id'],
              'question': q['question'] ?? '',
              'optional_text': q['optional_text'] ?? '',
              'question_file': q['question_file'] ?? '',
              'question_type': q['question_type'] ?? 'Reading',
              'choices': {
                'A': {
                  'choice_text': q['choice_A_text'] ?? '',
                  'choice_file': q['choice_A_file'] ?? '',
                  'word_formatting': (q['choice_A_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
                },
                'B': {
                  'choice_text': q['choice_B_text'] ?? '',
                  'choice_file': q['choice_B_file'] ?? '',
                  'word_formatting': (q['choice_B_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
                },
                'C': {
                  'choice_text': q['choice_C_text'] ?? '',
                  'choice_file': q['choice_C_file'] ?? '',
                  'word_formatting': (q['choice_C_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
                },
                'D': {
                  'choice_text': q['choice_D_text'] ?? '',
                  'choice_file': q['choice_D_file'] ?? '',
                  'word_formatting': (q['choice_D_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
                },
              },
              'correct_answer': q['correct_answer'] ?? '',
              'formatting': {
                'question_word_formatting': (q['question_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
                'optional_word_formatting': (q['optional_word_formatting'] as List?)?.map((w) => Map<String, dynamic>.from(w)).toList() ?? [],
              },
            };
          }).toList();
        });
      } else {
        setState(() => questions = []);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: ${response.statusCode}')),
        );
      }
    }
  } catch (e) {
    debugPrint('Error fetching questions: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: $e')),
      );
    }
  }
}

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

Future<String?> uploadFile(File? file, BuildContext context, String fileKey, Function(double) onProgress, StateSetter setDialogState) async {
  if (file == null) return null;
  try {
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }
    var fileSize = await file.length();
    debugPrint('Uploading file: ${file.path}, Size: $fileSize bytes');

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/quiz_set_detail_page.php'));
    
    // Add quiz_set_id as a field
    request.fields['quiz_set_id'] = widget.quizSetId.toString();
    request.fields['action'] = 'upload';
    
    var fileStream = file.openRead();
    var fileLength = fileSize;
    var byteCount = 0;
    var lastReportedProgress = 0.0;

    var stream = fileStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          byteCount += data.length;
          var currentProgress = (byteCount / fileLength).clamp(0.0, 1.0);
          var currentProgressPercent = (currentProgress * 100).floorToDouble() / 100;
          
          if (currentProgressPercent >= lastReportedProgress + 0.01 || currentProgressPercent == 1.0) {
            setDialogState(() {
              onProgress(currentProgressPercent);
            });
            lastReportedProgress = currentProgressPercent;
            debugPrint('Progress for $fileKey: ${(currentProgressPercent * 100).toStringAsFixed(0)}%');
          }
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          setDialogState(() {
            onProgress(1.0);
          });
          sink.close();
        },
      ),
    );

    var multipartFile = http.MultipartFile(
      fileKey,
      stream,
      fileLength,
      filename: file.path.split('/').last,
    );
    request.files.add(multipartFile);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    var responseData = response.body;

    debugPrint('Upload response: ${response.statusCode}, $responseData');

    if (response.statusCode == 200) {
      var json = jsonDecode(responseData);
      if (json['success'] == true) {
        return json['filename'] ?? file.path.split('/').last;
      }
      throw Exception('Upload failed: ${json['error'] ?? 'Unknown error'}');
    } else {
      throw Exception('Upload failed: ${response.statusCode}, $responseData');
    }
  } catch (e) {
    debugPrint('Upload error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    }
    return null;
  }
}

void _addQuestion() {
  TextEditingController questionController = TextEditingController();
  TextEditingController optionalTextController = TextEditingController();
  List<TextEditingController> choiceControllers = List.generate(4, (_) => TextEditingController());
  List<File?> choiceFiles = List.generate(4, (_) => null);
  File? questionFile;
  String selectedAnswer = 'A';
  String selectedQuestionType = 'Reading';
  Map<String, List<Map<String, dynamic>>> wordFormatting = {
    'question_word_formatting': [],
    'optional_word_formatting': [],
  };
  List<List<Map<String, dynamic>>> choiceWordFormatting = List.generate(4, (_) => []);
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
    existingChoiceFiles: ['A', 'B', 'C', 'D'].asMap().map((_, v) => MapEntry(v, '')),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question text cannot be empty')),
          );
        }
        return;
      }
      try {
        setState(() {
          isSaving = true;
          saveProgress = 0.0;
        });

        final totalFiles = (selectedQuestionFile != null ? 1 : 0) + selectedChoiceFiles.where((f) => f != null).length;
        int completedFiles = 0;

        void updateSaveProgress() {
          if (totalFiles > 0) {
            setState(() {
              saveProgress = (completedFiles / totalFiles) * 100;
            });
          }
        }

        final questionFileName = await uploadFile(
          selectedQuestionFile,
          context,
          'question',
          (progress) => uploadProgress['question'] = progress,
          setDialogState,
        ) ?? '';
        if (selectedQuestionFile != null) {
          completedFiles++;
          updateSaveProgress();
        }

        final choiceFileNamesFinal = await Future.wait(
          selectedChoiceFiles.asMap().entries.map((entry) async {
            final i = entry.key;
            final file = entry.value;
            final result = await uploadFile(
              file,
              context,
              'choice_$i',
              (progress) => uploadProgress['choice_$i'] = progress,
              setDialogState,
            ) ?? choiceFileNames[String.fromCharCode(65 + i)]!;
            if (file != null) {
              completedFiles++;
              updateSaveProgress();
            }
            return result;
          }),
        );

        final newQuestion = {
          'quiz_set_id': widget.quizSetId,
          'question': questionController.text,
          'optional_text': optionalTextController.text,
          'question_file': questionFileName,
          'question_type': updatedQuestionType,
          'choices': {
            'A': {
              'choice_text': choiceControllers[0].text,
              'choice_file': choiceFileNamesFinal[0],
              'word_formatting': choiceWordFormatting[0]
            },
            'B': {
              'choice_text': choiceControllers[1].text,
              'choice_file': choiceFileNamesFinal[1],
              'word_formatting': choiceWordFormatting[1]
            },
            'C': {
              'choice_text': choiceControllers[2].text,
              'choice_file': choiceFileNamesFinal[2],
              'word_formatting': choiceWordFormatting[2]
            },
            'D': {
              'choice_text': choiceControllers[3].text,
              'choice_file': choiceFileNamesFinal[3],
              'word_formatting': choiceWordFormatting[3]
            },
          },
          'correct_answer': selectedAnswer,
          'formatting': {
            'question_word_formatting': wordFormatting['question_word_formatting'],
            'optional_word_formatting': wordFormatting['optional_word_formatting'],
          },
        };

        final response = await _saveQuestionToBackend(newQuestion, false);
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            await fetchQuestions();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Question added successfully')),
              );
            }
          } else {
            throw Exception(responseData['error'] ?? 'Unknown error');
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error adding question: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding question: $e')),
          );
        }
      } finally {
        setState(() {
          isSaving = false;
          saveProgress = 0.0;
          uploadProgress.clear();
        });
      }
    },
  );
}

  void _editQuestion(int index) {
  TextEditingController questionController = TextEditingController(text: questions[index]['question']);
  TextEditingController optionalTextController = TextEditingController(text: questions[index]['optional_text']);
  List<TextEditingController> choiceControllers = List.generate(
      4, (i) => TextEditingController(text: questions[index]['choices'][String.fromCharCode(65 + i)]['choice_text']));
  List<File?> choiceFiles = List.generate(4, (_) => null);
  File? questionFile;
  String selectedAnswer = questions[index]['correct_answer'] ?? 'A';
  String selectedQuestionType = questions[index]['question_type'] ?? 'Reading';
  Map<String, List<Map<String, dynamic>>> wordFormatting = {
    'question_word_formatting': List<Map<String, dynamic>>.from(questions[index]['formatting']?['question_word_formatting'] ?? []),
    'optional_word_formatting': List<Map<String, dynamic>>.from(questions[index]['formatting']?['optional_word_formatting'] ?? []),
  };
  List<List<Map<String, dynamic>>> choiceWordFormatting = List.generate(
      4, (i) => List<Map<String, dynamic>>.from(questions[index]['choices'][String.fromCharCode(65 + i)]['word_formatting'] ?? []));
  String existingQuestionFile = questions[index]['question_file'] ?? '';
  Map<String, String> existingChoiceFiles = {
    'A': questions[index]['choices']['A']['choice_file'] ?? '',
    'B': questions[index]['choices']['B']['choice_file'] ?? '',
    'C': questions[index]['choices']['C']['choice_file'] ?? '',
    'D': questions[index]['choices']['D']['choice_file'] ?? '',
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question text cannot be empty')),
          );
        }
        return;
      }
      try {
        setState(() {
          isSaving = true;
          saveProgress = 0.0;
        });

        final totalFiles = (selectedQuestionFile != null ? 1 : 0) + selectedChoiceFiles.where((f) => f != null).length;
        int completedFiles = 0;

        void updateSaveProgress() {
          if (totalFiles > 0) {
            setState(() {
              saveProgress = (completedFiles / totalFiles) * 100;
            });
          }
        }

        final questionFileName = await uploadFile(
          selectedQuestionFile,
          context,
          'question',
          (progress) => uploadProgress['question'] = progress,
          setDialogState,
        ) ?? existingQuestionFile;
        if (selectedQuestionFile != null) {
          completedFiles++;
          updateSaveProgress();
        }

        final choiceFileNamesFinal = await Future.wait(
          selectedChoiceFiles.asMap().entries.map((entry) async {
            final i = entry.key;
            final file = entry.value;
            final result = await uploadFile(
              file,
              context,
              'choice_$i',
              (progress) => uploadProgress['choice_$i'] = progress,
              setDialogState,
            ) ?? choiceFileNames[String.fromCharCode(65 + i)]!;
            if (file != null) {
              completedFiles++;
              updateSaveProgress();
            }
            return result;
          }),
        );

        final updatedQuestion = {
          'id': questions[index]['id'],
          'quiz_set_id': widget.quizSetId,
          'question': questionController.text,
          'optional_text': optionalTextController.text,
          'question_file': questionFileName,
          'question_type': updatedQuestionType,
          'choices': {
            'A': {
              'choice_text': choiceControllers[0].text,
              'choice_file': choiceFileNamesFinal[0],
              'word_formatting': choiceWordFormatting[0]
            },
            'B': {
              'choice_text': choiceControllers[1].text,
              'choice_file': choiceFileNamesFinal[1],
              'word_formatting': choiceWordFormatting[1]
            },
            'C': {
              'choice_text': choiceControllers[2].text,
              'choice_file': choiceFileNamesFinal[2],
              'word_formatting': choiceWordFormatting[2]
            },
            'D': {
              'choice_text': choiceControllers[3].text,
              'choice_file': choiceFileNamesFinal[3],
              'word_formatting': choiceWordFormatting[3]
            },
          },
          'correct_answer': selectedAnswer,
          'formatting': {
            'question_word_formatting': wordFormatting['question_word_formatting'],
            'optional_word_formatting': wordFormatting['optional_word_formatting'],
          },
        };

        final response = await _saveQuestionToBackend(updatedQuestion, true);
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            await fetchQuestions();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Question updated successfully')),
              );
            }
          } else {
            throw Exception(responseData['error'] ?? 'Unknown error');
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error editing question: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing question: $e')),
          );
        }
      } finally {
        setState(() {
          isSaving = false;
          saveProgress = 0.0;
          uploadProgress.clear();
        });
      }
    },
  );
}

  Future<http.Response> _saveQuestionToBackend(Map<String, dynamic> question, bool isEditing) async {
    final uri = Uri.parse('$baseUrl/quiz_set_detail_page.php');
    final payload = {
      'action': isEditing ? 'edit' : 'add',
      'quiz_set_id': widget.quizSetId,
      'id': isEditing ? question['id'] : null,
      'question': question['question']?.toString() ?? '',
      'optional_text': question['optional_text']?.toString() ?? '',
      'question_file': question['question_file']?.toString() ?? '',
      'question_type': question['question_type']?.toString() ?? 'Reading',
      'correct_answer': question['correct_answer']?.toString() ?? '',
      'choices': {
        'A': {
          'choice_text': question['choices']['A']['choice_text']?.toString() ?? '',
          'choice_file': question['choices']['A']['choice_file']?.toString() ?? '',
          'word_formatting': question['choices']['A']['word_formatting'] ?? [],
        },
        'B': {
          'choice_text': question['choices']['B']['choice_text']?.toString() ?? '',
          'choice_file': question['choices']['B']['choice_file']?.toString() ?? '',
          'word_formatting': question['choices']['B']['word_formatting'] ?? [],
        },
        'C': {
          'choice_text': question['choices']['C']['choice_text']?.toString() ?? '',
          'choice_file': question['choices']['C']['choice_file']?.toString() ?? '',
          'word_formatting': question['choices']['C']['word_formatting'] ?? [],
        },
        'D': {
          'choice_text': question['choices']['D']['choice_text']?.toString() ?? '',
          'choice_file': question['choices']['D']['choice_file']?.toString() ?? '',
          'word_formatting': question['choices']['D']['word_formatting'] ?? [],
        },
      },
      'formatting': {
        'question_word_formatting': question['formatting']['question_word_formatting'] ?? [],
        'optional_word_formatting': question['formatting']['optional_word_formatting'] ?? [],
      },
    };

    try {
      debugPrint('Sending payload: ${json.encode(payload)}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      debugPrint('Response: ${response.statusCode}, ${response.body}');
      return response;
    } catch (e) {
      debugPrint('Error in _saveQuestionToBackend: $e');
      rethrow;
    }
  }

  void _deleteQuestion(int index) {
    final questionId = questions[index]['id'];
    _deleteQuestionFromBackend(questionId).then((success) {
      if (success) {
        setState(() {
          questions.removeAt(index);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question deleted successfully')),
          );
        }
      }
    });
  }

  Future<bool> _deleteQuestionFromBackend(dynamic questionId) async {
    try {
      final uri = Uri.parse('$baseUrl/quiz_set_detail_page.php');
      final response = await http.delete(
        uri,
        body: json.encode({
          'action': 'delete',
          'id': questionId
        }),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Delete response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return true;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete question: ${responseData['error']}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete question: ${response.statusCode}')),
          );
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting question: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting question: $e')),
        );
      }
      return false;
    }
  }

  void _confirmDeleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text("Are you sure you want to delete this question?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _deleteQuestion(index);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  bool _isImageFile(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;
    final ext = filePath.toLowerCase();
    return ext.endsWith('.png') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.gif');
  }

  Future<void> _openFile(String filePath) async {
    if (filePath.isEmpty) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = filePath.split('/').last;
      final localFile = File('${tempDir.path}/$fileName');

      final response = await http.get(Uri.parse('$baseUrl/$filePath'));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        final result = await OpenFile.open(localFile.path);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        onFileSelected(File(result.files.single.path!));
      }
    }

    bool isChoiceImageOrAudioOnly(int index) {
      final text = choiceControllers[index].text.trim();
      final file = localChoiceFiles[index]?.path.toLowerCase() ?? choiceFileNames[String.fromCharCode(65 + index)]?.toLowerCase() ?? '';
      return text.isEmpty &&
          (file.endsWith('.png') || file.endsWith('.jpg') || file.endsWith('.jpeg') || file.endsWith('.gif') ||
              file.endsWith('.mp3') || file.endsWith('.wav') || file.endsWith('.aac') || file.endsWith('.ogg'));
    }

    void updateWordFormatting(String text, String key, StateSetter setDialogState) {
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      setDialogState(() {
        final currentFormatting = wordFormatting[key]!;
        wordFormatting[key] = List.generate(
          words.length,
          (i) => i < currentFormatting.length ? currentFormatting[i] : {'bold': false, 'underline': false},
        );
      });
    }

    void updateChoiceWordFormatting(int index, StateSetter setDialogState) {
      final words = choiceControllers[index].text.split(' ').where((w) => w.isNotEmpty).toList();
      setDialogState(() {
        final currentFormatting = choiceWordFormatting[index];
        choiceWordFormatting[index] = List.generate(
          words.length,
          (i) => i < currentFormatting.length ? currentFormatting[i] : {'bold': false, 'underline': false},
        );
      });
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(labelText: "Enter question"),
                    maxLines: 2,
                    onChanged: (text) => updateWordFormatting(text, 'question_word_formatting', setDialogState),
                  ),
                  const SizedBox(height: 8),
                  if (questionController.text.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: questionController.text.split(' ').asMap().entries.map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        if (word.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            Text(
                              word,
                              style: TextStyle(
                                fontWeight: wordFormatting['question_word_formatting']!.isNotEmpty &&
                                        index < wordFormatting['question_word_formatting']!.length &&
                                        wordFormatting['question_word_formatting']![index]['bold'] == true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: wordFormatting['question_word_formatting']!.isNotEmpty &&
                                        index < wordFormatting['question_word_formatting']!.length &&
                                        wordFormatting['question_word_formatting']![index]['underline'] == true
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: wordFormatting['question_word_formatting']!.isNotEmpty &&
                                          index < wordFormatting['question_word_formatting']!.length
                                      ? wordFormatting['question_word_formatting']![index]['bold'] ?? false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['question_word_formatting']!.length > index) {
                                        wordFormatting['question_word_formatting']![index]['bold'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('B'),
                                Checkbox(
                                  value: wordFormatting['question_word_formatting']!.isNotEmpty &&
                                          index < wordFormatting['question_word_formatting']!.length
                                      ? wordFormatting['question_word_formatting']![index]['underline'] ?? false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['question_word_formatting']!.length > index) {
                                        wordFormatting['question_word_formatting']![index]['underline'] = value!;
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
                    onDragEntered: (_) => setDialogState(() => isDraggingQuestion = true),
                    onDragExited: (_) => setDialogState(() => isDraggingQuestion = false),
                    onDragDone: (details) async {
                      if (details.files.isNotEmpty) {
                        try {
                          final filePath = details.files.first.path;
                          final file = File(filePath);
                          if (await file.exists()) {
                            setDialogState(() => localQuestionFile = file);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cannot access file: Restricted or invalid path')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error accessing file: $e')),
                          );
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isDraggingQuestion ? Colors.blue : Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: isDraggingQuestion ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => pickFile((file) => setDialogState(() => localQuestionFile = file)),
                                  child: Text(localQuestionFile == null && localExistingQuestionFile.isEmpty
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
                                    onPressed: () => setDialogState(() => localExistingQuestionFile = ''),
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
                    decoration: const InputDecoration(labelText: "Optional Text (Inside Box)"),
                    maxLines: 2,
                    onChanged: (text) => updateWordFormatting(text, 'optional_word_formatting', setDialogState),
                  ),
                  const SizedBox(height: 8),
                  if (optionalTextController.text.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: optionalTextController.text.split(' ').asMap().entries.map((entry) {
                        final index = entry.key;
                        final word = entry.value;
                        if (word.isEmpty) return const SizedBox.shrink();
                        return Column(
                          children: [
                            Text(
                              word,
                              style: TextStyle(
                                fontWeight: wordFormatting['optional_word_formatting']!.isNotEmpty &&
                                        index < wordFormatting['optional_word_formatting']!.length &&
                                        wordFormatting['optional_word_formatting']![index]['bold'] == true
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                decoration: wordFormatting['optional_word_formatting']!.isNotEmpty &&
                                        index < wordFormatting['optional_word_formatting']!.length &&
                                        wordFormatting['optional_word_formatting']![index]['underline'] == true
                                    ? TextDecoration.underline
                                    : null,
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: wordFormatting['optional_word_formatting']!.isNotEmpty &&
                                          index < wordFormatting['optional_word_formatting']!.length
                                      ? wordFormatting['optional_word_formatting']![index]['bold'] ?? false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['optional_word_formatting']!.length > index) {
                                        wordFormatting['optional_word_formatting']![index]['bold'] = value!;
                                      }
                                    });
                                  },
                                ),
                                const Text('B'),
                                Checkbox(
                                  value: wordFormatting['optional_word_formatting']!.isNotEmpty &&
                                          index < wordFormatting['optional_word_formatting']!.length
                                      ? wordFormatting['optional_word_formatting']![index]['underline'] ?? false
                                      : false,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (wordFormatting['optional_word_formatting']!.length > index) {
                                        wordFormatting['optional_word_formatting']![index]['underline'] = value!;
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
                          decoration: InputDecoration(labelText: "Choice ${String.fromCharCode(65 + i)}"),
                          onChanged: (_) => updateChoiceWordFormatting(i, setDialogState),
                        ),
                        const SizedBox(height: 8),
                        if (choiceControllers[i].text.isNotEmpty && !isChoiceImageOrAudioOnly(i))
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
                                              choiceWordFormatting[i][index]['underline'] == true
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
                                            ? choiceWordFormatting[i][index]['underline'] ?? false
                                            : false,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            if (choiceWordFormatting[i].length > index) {
                                              choiceWordFormatting[i][index]['underline'] = value!;
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
                                    choiceFileNames[String.fromCharCode(65 + i)] = file.path.split('/').last;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cannot access file: Restricted or invalid path')),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error accessing file: $e')),
                                );
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: isDraggingChoice[i] ? Colors.blue : Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: isDraggingChoice[i] ? Colors.blue.withOpacity(0.1) : Colors.transparent,
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
                                              choiceFileNames[String.fromCharCode(65 + i)] = file.path.split('/').last;
                                            })),
                                        child: Text(localChoiceFiles[i] == null &&
                                                choiceFileNames[String.fromCharCode(65 + i)]!.isEmpty
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
                                    child: Text("File: ${localChoiceFiles[i]!.path.split('/').last}"),
                                  ),
                                if (localChoiceFiles[i] == null && choiceFileNames[String.fromCharCode(65 + i)]!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Text("File: ${choiceFileNames[String.fromCharCode(65 + i)]!.split('/').last}"),
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
                    onChanged: (String? newValue) => setDialogState(() => selectedAnswer = newValue!),
                    items: ['A', 'B', 'C', 'D'].map((value) => DropdownMenuItem(value: value, child: Text("Correct Answer: $value"))).toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedQuestionType,
                    onChanged: (String? newValue) => setDialogState(() => selectedQuestionType = newValue!),
                    items: ['Reading', 'Listening'].map((value) => DropdownMenuItem(value: value, child: Text("Question Type: $value"))).toList(),
                  ),
                  if (isSaving)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(
                        value: saveProgress / 100,
                        minHeight: 10,
                      ),
                    ),
                  if (isSaving)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Saving: ${saveProgress.toStringAsFixed(0)}%'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSaving
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
                      Navigator.of(context).pop();
                    },
              child: isSaving ? const Text("Saving...") : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(
      String text, List<Map<String, dynamic>> wordFormatting, TextStyle? baseStyle,
      {bool isQuestion = false, int? questionIndex, bool isOptionalText = false, bool isChoice = false, String? choiceLetter}) {
    if (isQuestion && questionIndex != null) {
      final prefix = "${questionIndex + 1}. ";
      final actualText = text.startsWith(prefix) ? text.substring(prefix.length) : text;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index ? wordFormatting[index]['bold'] ?? false : false;
              final underline = wordFormatting.length > index ? wordFormatting[index]['underline'] ?? false : false;
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
      final actualText = text.startsWith(prefix) ? text.substring(prefix.length) : text;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index ? wordFormatting[index]['bold'] ?? false : false;
              final underline = wordFormatting.length > index ? wordFormatting[index]['underline'] ?? false : false;
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
      final actualText = text.startsWith(prefix) ? text.substring(prefix.length) : text;
      final words = actualText.split(' ').where((w) => w.isNotEmpty).toList();

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: prefix, style: baseStyle),
            ...words.asMap().entries.map((entry) {
              final index = entry.key;
              final word = entry.value;
              final bold = wordFormatting.length > index ? wordFormatting[index]['bold'] ?? false : false;
              final underline = wordFormatting.length > index ? wordFormatting[index]['underline'] ?? false : false;
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
    } else {
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      return RichText(
        text: TextSpan(
          children: words.asMap().entries.map((entry) {
            final index = entry.key;
            final word = entry.value;
            final bold = wordFormatting.length > index ? wordFormatting[index]['bold'] ?? false : false;
            final underline = wordFormatting.length > index ? wordFormatting[index]['underline'] ?? false : false;
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quizSetName),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addQuestion,
              tooltip: 'Add Question',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: questions.isEmpty
                ? const Center(child: Text("No questions available."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormattedText(
                                "${index + 1}. ${question['question']}",
                                question['formatting']?['question_word_formatting'] ?? [],
                                Theme.of(context).textTheme.titleLarge,
                                isQuestion: true,
                                questionIndex: index,
                              ),
                              if (question['question_type'] != null && question['question_type'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    "Type: ${question['question_type']}",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.blue),
                                  ),
                                ),
                              if (question['question_file']?.isNotEmpty == true)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    _isImageFile(question['question_file'])
                                        ? Image.network(
                                            '$baseUrl/${question['question_file']}',
                                            height: 150,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => const Text('Image not available'),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _openFile(question['question_file']),
                                            child: Text("Open File: ${question['question_file'].split('/').last}"),
                                          ),
                                  ],
                                ),
                              if (question['optional_text']?.isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _buildFormattedText(
                                    "Note: ${question['optional_text']}",
                                    question['formatting']?['optional_word_formatting'] ?? [],
                                    Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
                                    isOptionalText: true,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              for (var choice in ['A', 'B', 'C', 'D'])
                                if (question['choices']?[choice] != null)
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
                                                "$choice) ${question['choices'][choice]['choice_text'] ?? ''}",
                                                question['choices'][choice]['word_formatting'] ?? [],
                                                Theme.of(context).textTheme.bodyLarge,
                                                isChoice: true,
                                                choiceLetter: choice,
                                              ),
                                            ),
                                            if (question['choices'][choice]['choice_file']?.isNotEmpty == true)
                                              Flexible(
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 16),
                                                  child: Text(
                                                    "File: ${question['choices'][choice]['choice_file'].split('/').last}",
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (question['choices'][choice]['choice_file']?.isNotEmpty == true)
                                          _isImageFile(question['choices'][choice]['choice_file'])
                                              ? Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Image.network(
                                                    '$baseUrl/${question['choices'][choice]['choice_file']}',
                                                    height: 150,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) => const Text('Image not available'),
                                                  ),
                                                )
                                              : Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: ElevatedButton(
                                                    onPressed: () => _openFile(question['choices'][choice]['choice_file']),
                                                    child: const Text("Open File"),
                                                  ),
                                                ),
                                      ],
                                    ),
                                  ),
                              const SizedBox(height: 16),
                              if (question['correct_answer'] != null && question['correct_answer'].isNotEmpty)
                                Text(
                                  "Correct Answer: ${question['correct_answer']}",
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _editQuestion(index),
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                      child: const Text("Edit"),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _confirmDeleteQuestion(index),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      child: const Text("Delete"),
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
        ),
      ),
    );
  }
}
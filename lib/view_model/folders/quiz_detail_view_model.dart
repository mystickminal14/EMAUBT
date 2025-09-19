import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:another_flushbar/flushbar.dart';
import 'package:ema_app/model/question_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/utils/utils.dart';

class QuizSetDetailViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  bool _isFetching = false;
  List<QuestionModel> questions = [];
  bool isLoading = false;
  bool isSaving = false;
  double saveProgress = 0.0;

  void _showSuccessMessage(BuildContext context, String message) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    ).show(context);
  }

  Future<void> fetchQuestions(int quizSetId) async {
    if (_isFetching) return;
    _isFetching = true;
    isLoading = true;
    questions.clear();
    _logger.i(
        "Starting fetchQuestions for quizSetId $quizSetId, current questions: $questions");
    notifyListeners();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          "${BaseUrl.baseUrl}/quiz_set_detail_page.php?quiz_set_id=$quizSetId&_=$timestamp";
      final response = await http.get(Uri.parse(url), headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 15));
      _logger.i("Server response: ${response.statusCode}, ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['questions'] != null &&
            data['questions'] is List) {
          questions = (data['questions'] as List)
              .map((q) => QuestionModel.fromJson(q))
              .toList();
          _logger.i("Fetched ${questions.length} questions: $questions");
        } else {
          questions = [];
          _logger.w(
              "No questions found or invalid response for quizSetId $quizSetId");
          Utils.noInternet('Failed to load questions: ${response.statusCode}');
        }
      } else {
        questions = [];
        _logger.w("Failed to fetch questions: ${response.statusCode}");
        Utils.noInternet('Failed to load questions: ${response.statusCode}');
      }
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e, stack) {
      _logger.e('Error fetching questions', error: e, stackTrace: stack);
      Utils.noInternet('Error loading questions: $e');
    } finally {
      isLoading = false;
      _isFetching = false;
      _logger.i("Fetch complete, questions: $questions");
      notifyListeners();
    }
  }

  Future<String?> uploadFile(
    File? file,
    BuildContext context,
    String fileKey,
    Function(double) onProgress,
  ) async {
    if (file == null) return null;
    try {
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }
      var fileSize = await file.length();
      _logger.i('Uploading file: ${file.path}, Size: $fileSize bytes');

      var request = http.MultipartRequest(
          'POST', Uri.parse('${BaseUrl.baseUrl}/quiz_set_detail_page.php'));
      request.fields['quiz_set_id'] = fileKey;
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
            var currentProgressPercent =
                (currentProgress * 100).floorToDouble() / 100;
            if (currentProgressPercent >= lastReportedProgress + 0.01 ||
                currentProgressPercent == 1.0) {
              onProgress(currentProgressPercent);
              lastReportedProgress = currentProgressPercent;
              _logger.i(
                  'Progress for $fileKey: ${(currentProgressPercent * 100).toStringAsFixed(0)}%');
            }
            sink.add(data);
          },
          handleError: (error, stackTrace, sink) {
            sink.addError(error, stackTrace);
          },
          handleDone: (sink) {
            onProgress(1.0);
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

      _logger.i('Upload response: ${response.statusCode}, $responseData');

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
      _logger.e('Upload error: $e');
      Utils.noInternet('Failed to upload file: $e');
      return null;
    }
  }

  Future<void> addQuestion(
      BuildContext context,
      Map<String, dynamic> questionData,
      File? questionFile,
      List<File?> choiceFiles,
      ) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;

    // Convert questionData['choices'] to Map<String, Choice>
    final Map<String, Choice> choices = {
      'A': Choice.fromJson(questionData['choices']['A']),
      'B': Choice.fromJson(questionData['choices']['B']),
      'C': Choice.fromJson(questionData['choices']['C']),
      'D': Choice.fromJson(questionData['choices']['D']),
    };

    final tempQuestion = QuestionModel(
      id: tempId,
      quizSetId: questionData['quiz_set_id'],
      question: questionData['question'],
      optionalText: questionData['optional_text'],
      questionFile: questionFile?.path ?? '',
      questionType: questionData['question_type'],
      choices: choices, // Use the converted choices
      correctAnswer: questionData['correct_answer'],
      formatting: questionData['formatting'],
    );

    questions.add(tempQuestion);
    _logger.i("Added temporary question: $tempQuestion");
    notifyListeners();

    try {
      isSaving = true;
      saveProgress = 0.0;
      notifyListeners();

      final totalFiles = (questionFile != null ? 1 : 0) +
          choiceFiles.where((f) => f != null).length;
      int completedFiles = 0;

      void updateSaveProgress() {
        if (totalFiles > 0) {
          saveProgress = (completedFiles / totalFiles) * 100;
          notifyListeners();
        }
      }

      final questionFileName = await uploadFile(
        questionFile,
        context,
        'question',
            (progress) {
          notifyListeners();
        },
      ) ??
          '';

      if (questionFile != null) {
        completedFiles++;
        updateSaveProgress();
      }

      final choiceFileNames = await Future.wait(
        choiceFiles.asMap().entries.map((entry) async {
          final i = entry.key;
          final file = entry.value;
          final result = await uploadFile(
            file,
            context,
            'choice_$i',
                (progress) {
              notifyListeners();
            },
          ) ??
              questionData['choices'][String.fromCharCode(65 + i)]['choice_file'] ??
              '';
          if (file != null) {
            completedFiles++;
            updateSaveProgress();
          }
          return result;
        }),
      );

      final newQuestion = {
        'quiz_set_id': questionData['quiz_set_id'],
        'question': questionData['question'],
        'optional_text': questionData['optional_text'],
        'question_file': questionFileName,
        'question_type': questionData['question_type'],
        'choices': {
          'A': {
            'choice_text': questionData['choices']['A']['choice_text'],
            'choice_file': choiceFileNames[0],
            'word_formatting': questionData['choices']['A']['word_formatting'],
          },
          'B': {
            'choice_text': questionData['choices']['B']['choice_text'],
            'choice_file': choiceFileNames[1],
            'word_formatting': questionData['choices']['B']['word_formatting'],
          },
          'C': {
            'choice_text': questionData['choices']['C']['choice_text'],
            'choice_file': choiceFileNames[2],
            'word_formatting': questionData['choices']['C']['word_formatting'],
          },
          'D': {
            'choice_text': questionData['choices']['D']['choice_text'],
            'choice_file': choiceFileNames[3],
            'word_formatting': questionData['choices']['D']['word_formatting'],
          },
        },
        'correct_answer': questionData['correct_answer'],
        'formatting': {
          'question_word_formatting': questionData['formatting']['question_word_formatting'],
          'optional_word_formatting': questionData['formatting']['optional_word_formatting'],
        },
      };

      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}/quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'add', ...newQuestion}),
      );

      _logger.i('Add question response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSuccessMessage(context, 'Question added successfully');
          await Future.delayed(const Duration(milliseconds: 500));
          await fetchQuestions(questionData['quiz_set_id']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to add question');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      questions.removeWhere((q) => q.id == tempId);
      _logger.e('Error adding question', error: e, stackTrace: stack);
      Utils.noInternet('Error adding question: $e');
    } finally {
      isSaving = false;
      saveProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> editQuestion(
      BuildContext context,
      int id,
      Map<String, dynamic> questionData,
      File? questionFile,
      List<File?> choiceFiles,
      ) async {
    final index = questions.indexWhere((q) => q.id == id);
    QuestionModel? oldQuestion;
    if (index != -1) {
      oldQuestion = questions[index];
      // Convert questionData['choices'] to Map<String, Choice> with null safety
      final Map<String, Choice> choices = {
        'A': Choice.fromJson(questionData['choices']['A'] ?? {'choice_text': '', 'choice_file': '', 'word_formatting': []}),
        'B': Choice.fromJson(questionData['choices']['B'] ?? {'choice_text': '', 'choice_file': '', 'word_formatting': []}),
        'C': Choice.fromJson(questionData['choices']['C'] ?? {'choice_text': '', 'choice_file': '', 'word_formatting': []}),
        'D': Choice.fromJson(questionData['choices']['D'] ?? {'choice_text': '', 'choice_file': '', 'word_formatting': []}),
      };
      questions[index] = QuestionModel(
        id: id,
        quizSetId: questionData['quiz_set_id'],
        question: questionData['question'],
        optionalText: questionData['optional_text'],
        questionFile: questionFile?.path ?? oldQuestion.questionFile,
        questionType: questionData['question_type'],
        choices: choices, // Use the converted choices
        correctAnswer: questionData['correct_answer'],
        formatting: questionData['formatting'],
      );
      _logger.i("Temporarily updated question at index $index: ${questions[index]}");
      notifyListeners();
    }

    try {
      isSaving = true;
      saveProgress = 0.0;
      notifyListeners();

      final totalFiles = (questionFile != null ? 1 : 0) +
          choiceFiles.where((f) => f != null).length;
      int completedFiles = 0;

      void updateSaveProgress() {
        if (totalFiles > 0) {
          saveProgress = (completedFiles / totalFiles) * 100;
          notifyListeners();
        }
      }

      final questionFileName = await uploadFile(
        questionFile,
        context,
        'question',
            (progress) {
          notifyListeners();
        },
      ) ??
          questionData['question_file'];
      if (questionFile != null) {
        completedFiles++;
        updateSaveProgress();
      }

      final choiceFileNames = await Future.wait(
        choiceFiles.asMap().entries.map((entry) async {
          final i = entry.key;
          final file = entry.value;
          final result = await uploadFile(
            file,
            context,
            'choice_$i',
                (progress) {
              notifyListeners();
            },
          ) ??
              questionData['choices'][String.fromCharCode(65 + i)]['choice_file'] ??
              '';
          if (file != null) {
            completedFiles++;
            updateSaveProgress();
          }
          return result;
        }),
      );

      final updatedQuestion = {
        'id': id,
        'quiz_set_id': questionData['quiz_set_id'],
        'question': questionData['question'],
        'optional_text': questionData['optional_text'],
        'question_file': questionFileName,
        'question_type': questionData['question_type'],
        'choices': {
          'A': {
            'choice_text': questionData['choices']['A']['choice_text'] ?? '',
            'choice_file': choiceFileNames[0],
            'word_formatting': questionData['choices']['A']['word_formatting'] ?? [],
          },
          'B': {
            'choice_text': questionData['choices']['B']['choice_text'] ?? '',
            'choice_file': choiceFileNames[1],
            'word_formatting': questionData['choices']['B']['word_formatting'] ?? [],
          },
          'C': {
            'choice_text': questionData['choices']['C']['choice_text'] ?? '',
            'choice_file': choiceFileNames[2],
            'word_formatting': questionData['choices']['C']['word_formatting'] ?? [],
          },
          'D': {
            'choice_text': questionData['choices']['D']['choice_text'] ?? '',
            'choice_file': choiceFileNames[3],
            'word_formatting': questionData['choices']['D']['word_formatting'] ?? [],
          },
        },
        'correct_answer': questionData['correct_answer'],
        'formatting': {
          'question_word_formatting': questionData['formatting']['question_word_formatting'] ?? [],
          'optional_word_formatting': questionData['formatting']['optional_word_formatting'] ?? [],
        },
      };

      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}/quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'edit', ...updatedQuestion}),
      );

      _logger.i('Edit question response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSuccessMessage(context, 'Question updated successfully');
          await Future.delayed(const Duration(milliseconds: 500));
          await fetchQuestions(questionData['quiz_set_id']);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to edit question');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      if (oldQuestion != null && index != -1) {
        questions[index] = oldQuestion;
        _logger.i("Reverted question at index $index to: $oldQuestion");
        notifyListeners();
      }
      _logger.e('Error editing question', error: e, stackTrace: stack);
      Utils.noInternet('Error editing question: $e');
    } finally {
      isSaving = false;
      saveProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> deleteQuestion(
      BuildContext context, int quizSetId, int id) async {
    final index = questions.indexWhere((q) => q.id == id);
    QuestionModel? removedQuestion;
    if (index != -1) {
      removedQuestion = questions[index];
      questions.removeAt(index);
      _logger
          .i("Temporarily removed question at index $index: $removedQuestion");
      notifyListeners();
    }

    try {
      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}/quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'delete', 'id': id}),
      );

      _logger.i(
          'Delete question response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          _showSuccessMessage(context, 'Question deleted successfully');
          await Future.delayed(const Duration(milliseconds: 500));
          await fetchQuestions(quizSetId);
        } else {
          throw Exception(responseData['error'] ?? 'Failed to delete question');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      if (removedQuestion != null && index != -1) {
        questions.insert(index, removedQuestion);
        _logger.i("Restored question at index $index: $removedQuestion");
        notifyListeners();
      }
      _logger.e('Error deleting question', error: e, stackTrace: stack);
      Utils.noInternet('Error deleting question: $e');
    }
  }
}

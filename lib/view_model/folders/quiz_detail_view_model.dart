import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:another_flushbar/flushbar.dart';
import 'package:ema_app/model/question_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

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

  // ========================= FETCH QUESTIONS ==============================
  Future<void> fetchQuestions(int quizSetId) async {
    if (_isFetching) return;
    _isFetching = true;
    isLoading = true;
    questions.clear();
    _logger.i("📥 Starting fetchQuestions for quizSetId: $quizSetId");
    notifyListeners();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          "${BaseUrl.baseUrl}quiz_set_detail_page.php?quiz_set_id=$quizSetId&_=$timestamp";
      _logger.i("🔗 Fetch URL: $url");

      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      _logger.i("✅ Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['questions'] != null &&
            data['questions'] is List) {
          questions = (data['questions'] as List)
              .map((q) => QuestionModel.fromJson(q))
              .toList();
          _logger.i("🧾 Fetched ${questions.length} questions successfully");
        } else {
          _logger.w("⚠️ Invalid or empty question list response");
          Utils.noInternet('Failed to load questions.');
        }
      } else {
        _logger.w("⚠️ Failed to fetch questions: ${response.statusCode}");
        Utils.noInternet('Failed to load questions.');
      }
    } on TimeoutException {
      _logger.w("⏱️ Timeout fetching questions");
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e, stack) {
      _logger.e('⛔ Error fetching questions', error: e, stackTrace: stack);
      Utils.noInternet('Error loading questions: $e');
    } finally {
      isLoading = false;
      _isFetching = false;
      _logger.i("🏁 Fetch complete. Total questions: ${questions.length}");
      notifyListeners();
    }
  }

  // ========================= FILE UPLOAD ==============================
  Future<String?> uploadFile(
      File? file,
      BuildContext context,
      String fileKey,
      Function(double) onProgress,
      int quizSetId,
      ) async {
    if (file == null) return null;
    try {
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }

      final ext = file.path.split('.').last.toLowerCase();
      final imageExts = ['jpg', 'jpeg', 'png', 'gif'];
      bool shouldCompress = imageExts.contains(ext) &&
          !kIsWeb &&
          !(Platform.isWindows || Platform.isLinux);  // Skip on Windows/Linux (unsupported), allow on macOS/mobile/web

      File? uploadFile = file;
      if (shouldCompress) {
        _logger.i("🗜️ Compressing image: ${file.path}");
        final tempDir = await getTemporaryDirectory();
        final targetPath =
            '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final Uint8List? compressedBytes =
        await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 85,
          format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
        );
        if (compressedBytes != null && compressedBytes.isNotEmpty) {
          await File(targetPath).writeAsBytes(compressedBytes);
          uploadFile = File(targetPath);
          _logger.i(
              "✅ Compression success. New size: ${compressedBytes.length} bytes");
        } else {
          _logger.w("⚠️ Image compression failed, uploading original file");
        }
      } else if (imageExts.contains(ext)) {
        _logger.i("🖥️ Skipping compression on unsupported platform: ${file.path}");
      } else {
        _logger.i("📄 Non-image file, skipping compression: ${file.path}");
      }

      final fileSize = await uploadFile.length();
      _logger.i("🚀 Uploading file: ${uploadFile.path} (${fileSize} bytes)");

      var request = http.MultipartRequest(
          'POST', Uri.parse('${BaseUrl.baseUrl}quiz_set_detail_page.php'));
      request.fields['quiz_set_id'] = quizSetId.toString();
      request.fields['action'] = 'upload';
      request.fields['file_key'] = fileKey;

      int byteCount = 0;
      final stream = uploadFile.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            byteCount += data.length;
            final progress = (byteCount / fileSize).clamp(0.0, 1.0);
            onProgress(progress);
            _logger.i(
                "📤 Upload progress for $fileKey: ${(progress * 100).toStringAsFixed(1)}%");
            sink.add(data);
          },
        ),
      );

      final multipartFile = http.MultipartFile(
        fileKey,
        stream,
        fileSize,
        filename: uploadFile.path.split(Platform.pathSeparator).last,  // Use platform separator for filename
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logger.i("✅ Upload response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          _logger.i("🎉 File uploaded successfully: ${jsonResponse['filename']}");
          return jsonResponse['filename'];
        } else {
          throw Exception(jsonResponse['error'] ?? 'Unknown upload error');
        }
      } else {
        throw Exception('Upload failed (${response.statusCode})');
      }
    } catch (e, stack) {
      _logger.e('⛔ Upload error', error: e, stackTrace: stack);
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
      choices: choices,
      correctAnswer: questionData['correct_answer'],
      formatting: questionData['formatting'],
    );

    questions.add(tempQuestion);
    _logger.i("🟢 Temporarily added question: $tempQuestion");
    notifyListeners();

    try {
      isSaving = true;
      saveProgress = 0.0;
      notifyListeners();

      _logger.i("🚀 Starting addQuestion upload process");

      final questionFileName = await uploadFile(
        questionFile,
        context,
        'question',
            (progress) {
          saveProgress = (saveProgress * 0.3) + (progress * 0.7);  // Simple weighted progress
          notifyListeners();
        },
        questionData['quiz_set_id'],
      ) ??
          '';

      final choiceFileNames = await Future.wait(
        choiceFiles.asMap().entries.map((entry) async {
          final i = entry.key;
          final file = entry.value;
          return await uploadFile(
            file,
            context,
            'choice_$i',
                (progress) {
              saveProgress += (1.0 / 4.0) * progress;  // Distribute across choices
              notifyListeners();
            },
            questionData['quiz_set_id'],
          ) ??
              '';
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
        'formatting': questionData['formatting'],
      };

      _logger.i("📡 Sending add question request: $newQuestion");

      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'add', ...newQuestion}),
      ).timeout(const Duration(seconds: 30));

      _logger.i("✅ Add question response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          _showSuccessMessage(context, 'Question added successfully');
          await fetchQuestions(questionData['quiz_set_id']);
        } else {
          throw Exception(jsonResponse['error'] ?? 'Failed to add question');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      questions.removeWhere((q) => q.id == tempId);
      _logger.e('⛔ Error adding question', error: e, stackTrace: stack);
      Utils.noInternet('Error adding question: $e');
    } finally {
      isSaving = false;
      saveProgress = 100.0;
      notifyListeners();
    }
  }

  // ========================= EDIT QUESTION ==============================
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
      final Map<String, Choice> choices = {
        'A': Choice.fromJson(questionData['choices']['A']),
        'B': Choice.fromJson(questionData['choices']['B']),
        'C': Choice.fromJson(questionData['choices']['C']),
        'D': Choice.fromJson(questionData['choices']['D']),
      };
      questions[index] = QuestionModel(
        id: id,
        quizSetId: questionData['quiz_set_id'],
        question: questionData['question'],
        optionalText: questionData['optional_text'],
        questionFile: questionFile?.path ?? oldQuestion.questionFile,
        questionType: questionData['question_type'],
        choices: choices,
        correctAnswer: questionData['correct_answer'],
        formatting: questionData['formatting'],
      );
      _logger.i("✏️ Temporarily updated question $id");
      notifyListeners();
    }

    try {
      isSaving = true;
      saveProgress = 0.0;
      notifyListeners();

      _logger.i("🚀 Starting editQuestion process for ID: $id");

      String questionFileName = questionData['question_file'] ?? '';
      if (questionFile != null) {
        questionFileName = await uploadFile(
          questionFile,
          context,
          'question',
              (progress) {
            saveProgress = (saveProgress * 0.3) + (progress * 0.7);
            notifyListeners();
          },
          questionData['quiz_set_id'],
        ) ??
            questionFileName;
      }

      final choiceFileNames = await Future.wait(
        choiceFiles.asMap().entries.map((entry) async {
          final i = entry.key;
          final file = entry.value;
          final choiceKey = String.fromCharCode(65 + i);
          String existingFile = questionData['choices'][choiceKey]['choice_file'] ?? '';
          if (file != null) {
            existingFile = await uploadFile(
              file,
              context,
              'choice_$i',
                  (progress) {
                saveProgress += (1.0 / 4.0) * progress;
                notifyListeners();
              },
              questionData['quiz_set_id'],
            ) ??
                existingFile;
          }
          return existingFile;
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
        'formatting': questionData['formatting'],
      };

      _logger.i("📡 Sending edit question request: $updatedQuestion");

      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}/quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'edit', ...updatedQuestion}),
      ).timeout(const Duration(seconds: 30));

      _logger.i("✅ Edit response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          _showSuccessMessage(context, 'Question updated successfully');
          await fetchQuestions(questionData['quiz_set_id']);
        } else {
          throw Exception(jsonResponse['error'] ?? 'Failed to edit question');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      if (oldQuestion != null && index != -1) {
        questions[index] = oldQuestion;
        _logger.w("↩️ Reverted changes for question $id");
        notifyListeners();
      }
      _logger.e('⛔ Error editing question', error: e, stackTrace: stack);
      Utils.noInternet('Error editing question: $e');
    } finally {
      isSaving = false;
      saveProgress = 100.0;
      notifyListeners();
    }
  }

  // ========================= DELETE QUESTION ==============================
  Future<void> deleteQuestion(
      BuildContext context, int quizSetId, int id) async {
    final index = questions.indexWhere((q) => q.id == id);
    QuestionModel? removedQuestion;
    if (index != -1) {
      removedQuestion = questions[index];
      questions.removeAt(index);
      _logger.i("🗑️ Temporarily removed question ID: $id");
      notifyListeners();
    }

    try {
      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}quiz_set_detail_page.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'delete', 'id': id}),
      ).timeout(const Duration(seconds: 15));

      _logger.i("✅ Delete response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          _showSuccessMessage(context, 'Question deleted successfully');
          await fetchQuestions(quizSetId);
        } else {
          throw Exception(jsonResponse['error'] ?? 'Failed to delete question');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e, stack) {
      if (removedQuestion != null && index != -1) {
        questions.insert(index, removedQuestion);
        _logger.w("↩️ Restored deleted question ID: $id");
        notifyListeners();
      }
      _logger.e('⛔ Error deleting question', error: e, stackTrace: stack);
      Utils.noInternet('Error deleting question: $e');
    }
  }
}
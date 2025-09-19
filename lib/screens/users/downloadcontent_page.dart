import 'dart:io';
import 'package:ema_app/screens/users/user_quiz_sets.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class DownloadContentPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;
  final String userId;
  final String userName;
  final String userEmail;
  final String role;
  final int folderId;
  final String folderName;
  final bool isAdmin;

  const DownloadContentPage({
    super.key,
    required this.quizSetId,
    required this.quizSetName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.role,
    required this.folderId,
    required this.folderName,
    required this.isAdmin,
    required String userIdentifier,
    required String fullName,
  });

  @override
  _DownloadContentPageState createState() => _DownloadContentPageState();
}

class _DownloadContentPageState extends State<DownloadContentPage> {
  double _progress = 0.0;
  String _status = 'Fetching quiz data...';
  final Map<String, String> _cachedFiles = {};
  bool _hasError = false;
  static const String baseUrl = 'https://theemaeducation.com';
  int _completedDownloads = 0;

  @override
  void initState() {
    super.initState();
    _preloadContent();
  }

  Future<void> _preloadContent() async {
    try {
      setState(() {
        _hasError = false;
        _status = 'Fetching quiz data...';
        _progress = 0.0;
        _completedDownloads = 0;
      });

      final response = await http
          .get(Uri.parse('$baseUrl/quiz_set_detail_page.php?quiz_set_id=${widget.quizSetId}'))
          .timeout(const Duration(seconds: 30));

      debugPrint('Fetch response: ${response.statusCode}');
      debugPrint('Fetch body: ${response.body}');

      if (response.statusCode != 200) {
        setState(() {
          _status = 'Failed to fetch quiz data (HTTP ${response.statusCode})';
          _hasError = true;
        });
        return;
      }

      final data = json.decode(response.body);
      
      if (data['success'] != true) {
        setState(() {
          _status = 'Server error: ${data['error'] ?? 'Unknown error'}';
          _hasError = true;
        });
        return;
      }

      List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(data['questions'] ?? []);

      if (questions.isEmpty) {
        setState(() {
          _status = 'No questions found in this quiz set';
          _hasError = true;
        });
        return;
      }

      List<String> mediaUrls = [];
      Set<String> uniqueUrls = {};

      for (var question in questions) {
        if (question['question_file']?.isNotEmpty == true) {
          String url = '$baseUrl/${question['question_file']}';
          if (!uniqueUrls.contains(url)) {
            mediaUrls.add(url);
            uniqueUrls.add(url);
          }
        }

        for (var choice in ['A', 'B', 'C', 'D']) {
          String? choiceFile = question['choice_${choice}_file'];
          if (choiceFile?.isNotEmpty == true) {
            String url = '$baseUrl/$choiceFile';
            if (!uniqueUrls.contains(url)) {
              mediaUrls.add(url);
              uniqueUrls.add(url);
            }
          }
        }
      }

      if (mediaUrls.isEmpty) {
        setState(() {
          _status = 'No media files to download';
          _progress = 100.0;
        });
        
        _navigateToQuizPage(data);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      int successfulDownloads = 0;
      int failedDownloads = 0;

      List<Future<void>> downloadFutures = [];

      for (String url in mediaUrls) {
        downloadFutures.add(_downloadWithRetry(url, tempDir.path).then((filePath) {
          if (filePath != null) {
            _cachedFiles[url] = filePath;
            successfulDownloads++;
          } else {
            failedDownloads++;
          }
          _updateProgress(mediaUrls.length);
        }).catchError((e) {
          failedDownloads++;
          _updateProgress(mediaUrls.length);
          debugPrint('Failed to download $url: $e');
        }));
      }

      setState(() {
        _status = 'Downloading files... (0/${mediaUrls.length})';
      });

      await Future.wait(downloadFutures);

      setState(() {
        _progress = 100.0;
        if (failedDownloads > 0) {
          _status = 'Download completed with some errors ($successfulDownloads successful, $failedDownloads failed)';
        } else {
          _status = 'Download complete! ($successfulDownloads files downloaded)';
        }
      });

      await Future.delayed(const Duration(milliseconds: 500));
      
      _navigateToQuizPage(data);

    } catch (e) {
      debugPrint('Error in _preloadContent: $e');
      setState(() {
        _status = 'Connection error: ${e.toString()}';
        _hasError = true;
      });
    }
  }

  Future<String?> _downloadWithRetry(String url, String tempPath) async {
    final fileName = url.split('/').last;
    final filePath = '$tempPath/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      return filePath;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final fileResponse = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (fileResponse.statusCode == 200) {
          await file.writeAsBytes(fileResponse.bodyBytes);
          debugPrint('Successfully downloaded: $fileName');
          return filePath;
        } else {
          debugPrint('Attempt $attempt failed for $fileName: HTTP ${fileResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('Attempt $attempt error for $fileName: $e');
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  void _updateProgress(int total) {
    setState(() {
      _completedDownloads++;
      _progress = (_completedDownloads / total) * 90;
      _status = 'Downloading files... ($_completedDownloads/$total)';
    });
  }

  void _navigateToQuizPage(Map<String, dynamic> data) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => UserQuizSetsPage(
          quizSetId: widget.quizSetId,
          quizSetName: widget.quizSetName,
          userId: widget.userId,
          userName: widget.userName,
          userEmail: widget.userEmail,
          role: widget.role,
          folderId: widget.folderId,
          folderName: widget.folderName,
          isAdmin: widget.isAdmin,
          userIdentifier: widget.isAdmin ? widget.userEmail : widget.userId,
          preStart: true,
          cachedFiles: _cachedFiles,
          quizData: data,
        ),
      ),
    );
  }

  void _retryDownload() {
    setState(() {
      _hasError = false;
      _status = 'Fetching quiz data...';
      _progress = 0.0;
      _cachedFiles.clear();
      _completedDownloads = 0;
    });
    _preloadContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preparing ${widget.quizSetName}'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_hasError) ...[
                CircularProgressIndicator(
                  value: _progress / 100,
                  strokeWidth: 6,
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${_progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                if (_progress > 0 && _progress < 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Please keep this screen open while downloading...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ] else ...[
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500, 
                    color: Colors.red
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _retryDownload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
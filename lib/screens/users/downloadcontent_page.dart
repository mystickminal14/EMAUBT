import 'dart:io';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/BaseApiService.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/screens/users/user_quiz_sets.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class DownloadContentPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;
  final String userId;
  final String userName;
  final String userEmail;
  final String role;
  final String folderId;
  final String folderName;
  final bool isAdmin;
  final String userIdentifier;
  final String fullName;

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
    required this.userIdentifier,
    required this.fullName,
  });

  @override
  _DownloadContentPageState createState() => _DownloadContentPageState();
}

class _DownloadContentPageState extends State<DownloadContentPage> {
  double _progress = 0.0;
  String _status = 'Fetching quiz data...';
  final Map<String, String> _cachedFiles = {};
  bool _hasError = false;
  int _completedDownloads = 0;
  int _totalFiles = 0;
  static const int maxConcurrentDownloads = 5;
  final BaseApiServices _apiService = NetworkApiService();

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
        _totalFiles = 0;
      });

      final data = await _apiService.getApiResponse(
          '${BaseUrl.baseUrl}/quiz_set_detail_page.php?quiz_set_id=${widget.quizSetId}');

      List<Map<String, dynamic>> questions =
      List<Map<String, dynamic>>.from(data['questions'] ?? []);

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
          String url = '${BaseUrl.baseUrl}/${question['question_file']}';
          if (!uniqueUrls.contains(url)) {
            mediaUrls.add(url);
            uniqueUrls.add(url);
          }
        }

        for (var choice in ['A', 'B', 'C', 'D']) {
          String? choiceFile = question['choice_${choice}_file'];
          if (choiceFile?.isNotEmpty == true) {
            String url = '${BaseUrl.baseUrl}/$choiceFile';
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

      _totalFiles = mediaUrls.length;
      final tempDir = await getTemporaryDirectory();
      int successfulDownloads = 0;
      int failedDownloads = 0;

      // Use a semaphore-like approach to limit concurrent downloads
      final downloadQueue = <Future<void>>[];
      int activeDownloads = 0;

      for (String url in mediaUrls) {
        if (activeDownloads >= maxConcurrentDownloads) {
          await Future.any(downloadQueue);
          activeDownloads--;
        }

        final future = _downloadWithRetry(url, tempDir.path, (progress) {
          setState(() {
            _progress = (_completedDownloads + progress) / _totalFiles * 90;
          });
        }).then((filePath) {
          if (filePath != null) {
            _cachedFiles[url] = filePath;
            successfulDownloads++;
          } else {
            failedDownloads++;
          }
          _updateProgress();
        }).catchError((e) {
          failedDownloads++;
          _updateProgress();
          debugPrint('Failed to download $url: $e');
        });

        downloadQueue.add(future);
        activeDownloads++;
      }

      setState(() {
        _status = 'Downloading files... (0/$_totalFiles)';
      });

      await Future.wait(downloadQueue);

      setState(() {
        _progress = 100.0;
        if (failedDownloads > 0) {
          _status =
          'Download completed with some errors ($successfulDownloads successful, $failedDownloads failed)';
        } else {
          _status =
          'Download complete! ($successfulDownloads files downloaded)';
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

  Future<String?> _downloadWithRetry(String url, String tempPath, Function(double) onProgress) async {
    final fileName = url.split('/').last;
    final filePath = '$tempPath/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      return filePath;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(url));
          final response = await client.send(request).timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) {
            debugPrint('Attempt $attempt failed for $fileName: HTTP ${response.statusCode}');
            continue;
          }

          final sink = file.openWrite();
          int receivedBytes = 0;
          final totalBytes = response.contentLength ?? 0;

          await for (var chunk in response.stream) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              onProgress(receivedBytes / totalBytes);
            }
          }
          await sink.close();
          debugPrint('Successfully downloaded: $fileName');
          return filePath;
        } finally {
          client.close();
        }
      } catch (e) {
        debugPrint('Attempt $attempt error for $fileName: $e');
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 1000 * (1 << attempt))); // Exponential backoff
      }
    }
    return null;
  }

  void _updateProgress() {
    setState(() {
      _completedDownloads++;
      _status = 'Downloading files... ($_completedDownloads/$_totalFiles)';
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
      _totalFiles = 0;
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
                      fontSize: 16, fontWeight: FontWeight.w500),
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
                      color: Colors.red),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
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
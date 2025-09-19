import 'dart:async';
import 'package:ema_app/screens/users/downloadcontent_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as webview_windows;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

class UserFolderDetailsPage extends StatefulWidget {
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? profileImage;
  final String? userEmail;

  const UserFolderDetailsPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.profileImage,
    this.userEmail,
    required String userId,
    required String userName,
    required String role,
  });

  @override
  _UserFolderDetailsPageState createState() => _UserFolderDetailsPageState();
}

class _UserFolderDetailsPageState extends State<UserFolderDetailsPage> {
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late SharedPreferences _prefs;
  String? _cachedFullName;
  String? _cachedProfileImage;
  String? _cachedUserEmail;
  final Dio _dio = Dio();

  ScreenSize _getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenSize.small;
    if (width < 1024) return ScreenSize.medium;
    return ScreenSize.large;
  }

  ResponsiveDimensions _getResponsiveDimensions(BuildContext context) {
    final screenSize = _getScreenSize(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final orientation = MediaQuery.of(context).orientation;

    switch (screenSize) {
      case ScreenSize.small:
        return ResponsiveDimensions(
          padding: screenWidth * 0.04,
          titleFontSize: orientation == Orientation.portrait
              ? screenWidth * 0.045
              : screenWidth * 0.035,
          itemWidth: screenWidth * 0.9,
          itemHeight: orientation == Orientation.portrait
              ? screenHeight * 0.08
              : screenHeight * 0.12,
          itemFontSize: orientation == Orientation.portrait
              ? screenWidth * 0.04
              : screenWidth * 0.03,
          iconSize: screenWidth * 0.06,
          crossAxisCount: 1,
        );
      case ScreenSize.medium:
        return ResponsiveDimensions(
          padding: screenWidth * 0.03,
          titleFontSize: orientation == Orientation.portrait
              ? screenWidth * 0.035
              : screenWidth * 0.03,
          itemWidth: screenWidth * 0.8,
          itemHeight: orientation == Orientation.portrait
              ? screenHeight * 0.09
              : screenHeight * 0.14,
          itemFontSize: orientation == Orientation.portrait
              ? screenWidth * 0.035
              : screenWidth * 0.025,
          iconSize: screenWidth * 0.05,
          crossAxisCount: 1,
        );
      case ScreenSize.large:
        return ResponsiveDimensions(
          padding: 24.0,
          titleFontSize: orientation == Orientation.portrait ? 24.0 : 20.0,
          itemWidth:
              orientation == Orientation.portrait ? 400.0 : screenWidth * 0.45,
          itemHeight: orientation == Orientation.portrait ? 60.0 : 80.0,
          itemFontSize: orientation == Orientation.portrait ? 16.0 : 14.0,
          iconSize: 28.0,
          crossAxisCount: 1,
        );
    }
  }

  String _getFileType(String fileName) {
    if (fileName.isEmpty) return 'other';
    final extension = fileName.split('.').last.toLowerCase().trim();
    if (['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)) return 'audio';
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return 'image';
    }
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'].contains(extension)) {
      return 'video';
    }
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp']
        .contains(extension)) {
      return 'office';
    }
    if (['pdf'].contains(extension)) return 'pdf';
    return 'other';
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    }
    _initSharedPreferences();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchFiles();
    await _fetchQuizSets();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (widget.fullName != null && widget.fullName!.isNotEmpty) {
      await _prefs.setString('fullName', widget.fullName!);
    }
    if (widget.profileImage != null && widget.profileImage!.isNotEmpty) {
      await _prefs.setString('profileImage', widget.profileImage!);
    }
    if (widget.userEmail != null && widget.userEmail!.isNotEmpty) {
      await _prefs.setString('userEmail', widget.userEmail!);
    }
    if (mounted) {
      setState(() {
        _cachedFullName = _prefs.getString('fullName') ?? '';
        _cachedProfileImage = _prefs.getString('profileImage') ?? '';
        _cachedUserEmail = _prefs.getString('userEmail') ?? '';
      });
    }
  }

  Future<void> _fetchFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url =
          'https://theemaeducation.com/folder_details_page.php?action=get_files&folder_id=${widget.folderId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          List<Map<String, dynamic>> allFiles =
              List<Map<String, dynamic>>.from(data['data']).map((file) {
            file['id'] = int.parse(file['id'].toString());
            return file;
          }).toList();

          for (var file in allFiles) {
            var accessResult = await _checkAccess(file['id'], 'file');
            file['can_access'] = accessResult['can_access'];
            file['has_permission'] = accessResult['has_permission'];
            file['is_active'] = accessResult['is_active'];
            file['access_times'] = accessResult['access_times'];
            file['times_accessed'] = accessResult['times_accessed'];
            if (kDebugMode) {
              print('File: ${file['name']}, can_access: ${file['can_access']}, has_permission: ${file['has_permission']}, is_active: ${file['is_active']}');
            }
          }

          if (mounted) {
            setState(() {
              files = allFiles;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Failed to fetch files: ${data['message']}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server error while fetching files')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching files: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchQuizSets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url =
          'https://theemaeducation.com/folder_details_page.php?action=get_quiz_sets&folder_id=${widget.folderId}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          List<Map<String, dynamic>> allQuizSets =
              List<Map<String, dynamic>>.from(data['data']).map((quizSet) {
            quizSet['id'] = int.parse(quizSet['id'].toString());
            return quizSet;
          }).toList();

          allQuizSets.sort((a, b) => a['id'].compareTo(b['id']));

          for (var quizSet in allQuizSets) {
            var accessResult = await _checkAccess(quizSet['id'], 'quiz_set');
            quizSet['can_access'] = accessResult['can_access'];
            quizSet['has_permission'] = accessResult['has_permission'];
            quizSet['is_active'] = accessResult['is_active'];
            quizSet['access_times'] = accessResult['access_times'];
            quizSet['times_accessed'] = accessResult['times_accessed'];
            if (kDebugMode) {
              print('QuizSet: ${quizSet['name']}, can_access: ${quizSet['can_access']}, has_permission: ${quizSet['has_permission']}, is_active: ${quizSet['is_active']}');
            }
          }

          if (mounted) {
            setState(() {
              quizSets = allQuizSets;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Failed to fetch quiz sets: ${data['message']}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Server error while fetching quiz sets')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching quiz sets: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _fetchFilePath(int fileId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://theemaeducation.com/folder_details_page.php?action=get_file_by_id&file_id=$fileId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success" && data['data'] != null) {
          return data['data']['file_path'];
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching file path: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _checkAccess(int itemId, String itemType) async {
    if (widget.isAdmin) {
      return {
        'can_access': true,
        'has_permission': true,
        'is_active': 1,
        'access_times': -1,
        'times_accessed': 0,
      };
    }

    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/check_access.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'identifier': widget.userIdentifier.isEmpty ? 'guest' : widget.userIdentifier,
          'is_admin': 'false',
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          print('CheckAccess Response for Item ID: $itemId, Type: $itemType - $data');
        }
        if (data['success'] == true) {
          return {
            'can_access': data['can_access'] == true,
            'has_permission': data['has_permission'] == true,
            'is_active': data['is_active'] ?? 0,
            'access_times': data['access_times'] ?? -1,
            'times_accessed': data['times_accessed'] ?? 0,
          };
        }
      }
      return {
        'can_access': false,
        'has_permission': false,
        'is_active': 0,
        'access_times': -1,
        'times_accessed': 0,
      };
    } catch (e) {
      if (kDebugMode) print('Error checking access for Item ID: $itemId, Type: $itemType - $e');
      return {
        'can_access': false,
        'has_permission': false,
        'is_active': 0,
        'access_times': -1,
        'times_accessed': 0,
      };
    }
  }

  Future<bool> _incrementAccessCount(int itemId, String itemType) async {
    if (widget.userIdentifier.isEmpty || widget.isAdmin) return true;

    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/increment_access.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'identifier': widget.userIdentifier,
          'is_admin': 'false',
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('Increment Access Response for Item ID: $itemId, Type: $itemType - $data');
        return data['success'] == true;
      }
    } catch (e) {
      if (kDebugMode) print('Error incrementing access count: $e');
      return false;
    }
    return false;
  }

  Widget _buildItemIcon(Map<String, dynamic> item, IconData defaultIcon) {
    if (item['icon_path'] != null && item['icon_path'].isNotEmpty) {
      return Image.network(
        'https://theemaeducation.com/${item['icon_path']}',
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(defaultIcon, size: 28, color: Colors.teal[800]),
      );
    }
    return Icon(defaultIcon, size: 28, color: Colors.teal[800]);
  }

  void _showAccessDetailsDialog(Map<String, dynamic> item, String itemType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Access Details for ${item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.isAdmin
                ? 'Granted Access Times: Unlimited (Admin)'
                : item['has_permission'] == true
                    ? (item['access_times'] == -1
                        ? 'Granted Access Times: Unlimited'
                        : 'Granted Access Times: ${item['access_times']}')
                    : 'Access Denied: Contact Admin to Activate'),
            if (item['has_permission'] == true)
              Text('Times Accessed by You: ${item['times_accessed']}'),
            if (item['has_permission'] == true && item['is_active'] == 0)
              const Text('Item not activated by admin'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showAudioPlayer(String url, String fileName) async {
    String? localFilePath;
    bool isAudioLoading = true;
    Duration? totalDuration;
    Function(void Function())? dialogStateUpdater;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isPlaying = false;
        Duration position = Duration.zero;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateUpdater = setDialogState;

            _audioPlayer.onPositionChanged.listen((p) {
              if (mounted) setDialogState(() => position = p);
            });
            _audioPlayer.onPlayerStateChanged.listen((state) {
              if (mounted) setDialogState(() => isPlaying = state == PlayerState.playing);
            });

            return AlertDialog(
              title: Text(fileName, style: const TextStyle(fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAudioLoading)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Loading Audio...', style: TextStyle(fontSize: 14)),
                        ],
                      )
                    else ...[
                      Text('Position: ${position.inSeconds} s', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('State: ${isPlaying ? "Playing" : "Paused/Stopped"}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await _audioPlayer.play(
                                kIsWeb ? UrlSource(url) : DeviceFileSource(localFilePath!),
                              );
                              setDialogState(() => isPlaying = true);
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
                            child: const Text('Play', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _audioPlayer.pause();
                              setDialogState(() => isPlaying = false);
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
                            child: const Text('Pause', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _audioPlayer.stop();
                              setDialogState(() {
                                isPlaying = false;
                                position = Duration.zero;
                              });
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 36)),
                            child: const Text('Stop', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final currentPosition = await _audioPlayer.getCurrentPosition();
                              if (currentPosition != null) {
                                final newPosition = currentPosition - const Duration(seconds: 10);
                                await _audioPlayer.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
                                setDialogState(() => position = newPosition > Duration.zero ? newPosition : Duration.zero);
                              }
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 36)),
                            child: const Text('← 10s', style: TextStyle(fontSize: 12)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final currentPosition = await _audioPlayer.getCurrentPosition();
                              if (currentPosition != null && totalDuration != null) {
                                final newPosition = currentPosition + const Duration(seconds: 10);
                                await _audioPlayer.seek(newPosition < totalDuration! ? newPosition : totalDuration!);
                                setDialogState(() => position = newPosition < totalDuration! ? newPosition : totalDuration!);
                              }
                            },
                            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 36)),
                            child: const Text('10s →', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await _audioPlayer.stop();
                      await _audioPlayer.release();
                      if (!kIsWeb && localFilePath != null && await File(localFilePath).exists()) {
                        await File(localFilePath).delete();
                      }
                    } catch (e) {
                      if (kDebugMode) print('Error during cleanup: $e');
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );

    try {
      await _audioPlayer.stop();
      await _audioPlayer.release();

      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/${fileName.replaceAll(RegExp(r'[^\w.]'), '_')}';
        final file = File(filePath);
        localFilePath = filePath;

        final response = await http.head(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Audio file not accessible: ${response.statusCode}');
        }

        if (mounted && dialogStateUpdater != null) {
          dialogStateUpdater!(() => isAudioLoading = true);
        }

        await _dio.download(url, filePath);
        if (!await file.exists()) {
          throw Exception('Failed to download audio file');
        }

        await _audioPlayer.setSource(DeviceFileSource(filePath));
        if (mounted && dialogStateUpdater != null) {
          dialogStateUpdater!(() => isAudioLoading = false);
        }
        await _audioPlayer.play(DeviceFileSource(filePath));

        _audioPlayer.onPlayerComplete.listen((_) async {
          try {
            if (await file.exists()) await file.delete();
          } catch (e) {
            if (kDebugMode) print('Error deleting file: $e');
          }
        });
      } else {
        await _audioPlayer.setSourceUrl(url);
        if (mounted && dialogStateUpdater != null) {
          dialogStateUpdater!(() => isAudioLoading = false);
        }
        await _audioPlayer.play(UrlSource(url));
      }

      _audioPlayer.onDurationChanged.listen((d) {
        totalDuration = d;
      });
    } catch (e) {
      if (kDebugMode) print('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
        Navigator.pop(context);
      }
    }
  }

  void _showImageViewer(String url, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: CachedNetworkImage(
          imageUrl: url,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showVideoPlayer(String url, String fileName) async {
    try {
      final modifiedUrl = Uri.parse(url).replace(
        queryParameters: {
          ...Uri.parse(url).queryParameters,
          '_cache_bust': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ).toString();

      if (kIsWeb || Platform.isWindows) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WindowsWebViewPage(
              url: modifiedUrl,
              fileName: fileName,
              isVideo: true,
              isAdmin: widget.isAdmin,
            ),
          ),
        );
      } else {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(modifiedUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
        try {
          await controller.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Video initialization timed out');
            },
          );
          await controller.play();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(
                  url: modifiedUrl,
                  fileName: fileName,
                  controller: controller,
                ),
              ),
            ).then((_) async {
              await controller.pause();
              await controller.dispose();
            });
          } else {
            await controller.dispose();
          }
        } catch (e) {
          if (kDebugMode) print('Video init error on Android: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error initializing video: $e')),
            );
          }
          await controller.dispose();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Video setup error on Android: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: $e')),
        );
      }
    }
  }

  Future<void> _handleFileTap(Map<String, dynamic> file) async {
    if (file['can_access'] != true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Access Denied'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file['has_permission'] == true
                  ? 'This file is not activated by admin.'
                  : 'This file requires admin activation.'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _makePhoneCall('+9779851213520', context),
                child: const Text(
                  'Phone: +9779851213520',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openFacebook(context),
                child: const Text(
                  'Facebook: yogendra.wagle.12',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    if (file['file_path'] == null) {
      final fetchedFilePath = await _fetchFilePath(file['id']);
      if (fetchedFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to load file: File path not found')),
          );
        }
        return;
      }
      file['file_path'] = fetchedFilePath;
    }

    if (!widget.isAdmin && widget.userIdentifier.isNotEmpty) {
      bool incremented = await _incrementAccessCount(file['id'], 'file');
      if (!incremented) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update access count')),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        file['times_accessed'] = (file['times_accessed'] ?? 0) + 1;
      });
    }

    final fileUrl = 'https://theemaeducation.com/${file['file_path']}';
    final encodedFileUrl = Uri.encodeFull(fileUrl);
    final viewerUrl =
        'https://docs.google.com/viewer?url=$encodedFileUrl&embedded=true&_cache_bust=${DateTime.now().millisecondsSinceEpoch}';
    final fileType = _getFileType(file['name'] ?? '');
    if (kDebugMode) {
      print('File: ${file['name']}, Type: $fileType, URL: $fileUrl');
    }

    switch (fileType) {
      case 'audio':
        await _showAudioPlayer(fileUrl, file['name']);
        break;
      case 'image':
        _showImageViewer(fileUrl, file['name']);
        break;
      case 'video':
        await _showVideoPlayer(fileUrl, file['name']);
        break;
      case 'pdf':
      case 'office':
        if (kIsWeb || Platform.isWindows) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WindowsWebViewPage(
                url: viewerUrl,
                fileName: file['name'],
                isVideo: false,
                isAdmin: widget.isAdmin,
              ),
            ),
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document loading timed out')),
                );
              }
            },
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(
                url: viewerUrl,
                fileName: file['name'],
              ),
            ),
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document loading timed out')),
                );
              }
            },
          );
        }
        break;
      default:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported file type: ${file['name']}')),
          );
        }
        break;
    }
  }

  Future<void> _openFacebook(BuildContext context) async {
    const String pageId = 'yogendra.wagle.12';
    const String fallbackUrl = 'https://www.facebook.com/yogendra.wagle.12';
    String fbProtocolUrl = Platform.isIOS
        ? 'fb://profile/$pageId'
        : Platform.isAndroid
            ? 'fb://page/$pageId'
            : fallbackUrl;

    try {
      final Uri fbUri = Uri.parse(fbProtocolUrl);
      final Uri webUri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(fbUri)) {
        await launchUrl(fbUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open Facebook: $e')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No app available to make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make phone call: $e')),
        );
      }
    }
  }

  Widget _buildItemTile(
    ResponsiveDimensions dimensions,
    Map<String, dynamic> item,
    String itemType,
    VoidCallback onTap,
  ) {
    final hasPermission = item['has_permission'] == true;
    final isActive = item['is_active'] == 1;
    final fileType = itemType == 'file' ? _getFileType(item['name'] ?? '') : null;

    if (kDebugMode) {
      print('Building Tile for Item: ${item['name']}, has_permission: $hasPermission, is_active: $isActive');
    }

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: dimensions.itemWidth,
            height: dimensions.itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildItemIcon(
                    item,
                    itemType == 'file' ? Icons.insert_drive_file : Icons.quiz),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item['name'] ??
                        (itemType == 'file'
                            ? 'Unnamed File'
                            : 'Unnamed Quiz Set'),
                    style: TextStyle(
                      fontSize: dimensions.itemFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.teal[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                hasPermission
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green[600] : Colors.green[300],
                          border: Border.all(
                            color: isActive ? Colors.green[600]! : Colors.green[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          itemType == 'quiz_set' ||
                                  fileType == 'pdf' ||
                                  fileType == 'office' ||
                                  fileType == 'image'
                              ? 'Open'
                              : 'Play',
                          style: TextStyle(
                            fontSize: dimensions.itemFontSize * 0.8,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Contact Admin',
                        style: TextStyle(
                          fontSize: dimensions.itemFontSize * 0.8,
                          color: Colors.red[600],
                        ),
                      ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.teal),
                  iconSize: dimensions.iconSize * 0.7,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showAccessDetailsDialog(item, itemType),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveItemGrid(
      BuildContext context,
      ResponsiveDimensions dimensions,
      List<Map<String, dynamic>> items,
      String itemType) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildItemTile(dimensions, item, itemType, () async {
              if (itemType == 'quiz_set') {
  if (item['can_access'] != true) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['has_permission'] == true
                ? 'This quiz set is not activated by admin.'
                : 'This quiz set requires admin activation.'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _makePhoneCall('+9779851213520', context),
              child: const Text(
                'Phone: +9779851213520',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openFacebook(context),
              child: const Text(
                'Facebook: yogendra.wagle.12',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
    return;
  }

  if (!widget.isAdmin && widget.userIdentifier.isNotEmpty) {
    bool incremented = await _incrementAccessCount(item['id'], 'quiz_set');
    if (!incremented && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update access count')),
      );
      return;
    }
  }

  if (mounted && !widget.isAdmin) {
    setState(() {
      item['times_accessed'] = (item['times_accessed'] ?? 0) + 1;
    });
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DownloadContentPage(
        quizSetId: item['id'],
        quizSetName: item['name'],
        userIdentifier: widget.userIdentifier.isEmpty
            ? 'guest'
            : widget.userIdentifier,
        isAdmin: widget.isAdmin,
        fullName: _cachedFullName ?? '',
        userEmail: widget.isAdmin ? widget.userIdentifier : _cachedUserEmail ?? '',
        folderId: widget.folderId,
        folderName: widget.folderName, userId: '', userName: '', role: '',
      ),
    ),
  ).then((_) => _fetchQuizSets());
} else {
  _handleFileTap(item);
}
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: TextStyle(
            fontSize: _getScreenSize(context) == ScreenSize.small
                ? screenWidth * 0.045
                : _getScreenSize(context) == ScreenSize.medium
                    ? screenWidth * 0.03
                    : 20.0,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 6,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.cyanAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white, size: 24),
            tooltip: 'Go to Home',
            onPressed: () {
              if (widget.userIdentifier.isNotEmpty &&
                  !widget.userIdentifier.contains('guest')) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserHomePage(
                      userIdentifier: widget.userIdentifier,
                      isAdmin: widget.isAdmin,
                      fullName: _cachedFullName ?? '',
                      profileImage: _cachedProfileImage ?? '',
                      userEmail: _cachedUserEmail ?? widget.userIdentifier,
                      folderId: null,
                      folderName: '',
                    ),
                  ),
                  (route) => false,
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(
                      userIdentifier: '',
                      isAdmin: false,
                      fullName: _cachedFullName ?? '',
                    ),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.teal[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(dimensions.padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (quizSets.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Quiz Sets",
                          style: TextStyle(
                            fontSize: dimensions.titleFontSize,
                            color: Colors.teal[800],
                          ),
                        ),
                      ),
                      _buildResponsiveItemGrid(
                          context, dimensions, quizSets, 'quiz_set'),
                      const Divider(thickness: 0.5, color: Colors.teal),
                    ],
                    if (files.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Files",
                          style: TextStyle(
                            fontSize: dimensions.titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[800],
                          ),
                        ),
                      ),
                      _buildResponsiveItemGrid(
                          context, dimensions, files, 'file'),
                      const Divider(thickness: 0.5, color: Colors.teal),
                    ],
                  ],
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}

enum ScreenSize { small, medium, large }

class ResponsiveDimensions {
  final double padding;
  final double titleFontSize;
  final double itemWidth;
  final double itemHeight;
  final double itemFontSize;
  final double iconSize;
  final int crossAxisCount;

  ResponsiveDimensions({
    required this.padding,
    required this.titleFontSize,
    required this.itemWidth,
    required this.itemHeight,
    required this.itemFontSize,
    required this.iconSize,
    required this.crossAxisCount,
  });
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String fileName;
  final VideoPlayerController controller;

  const VideoPlayerPage({
    super.key,
    required this.url,
    required this.fileName,
    required this.controller,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.controller.value.isInitialized) {
      _isInitialized = true;
      _duration = widget.controller.value.duration;
      widget.controller.play();
    } else {
      widget.controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video initialization timed out')),
            );
          }
        },
      ).then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _duration = widget.controller.value.duration;
            widget.controller.play();
          });
        }
      }).catchError((e) {
        if (kDebugMode) print('Video init error on Android: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing video: $e')),
          );
        }
      });
    }
    widget.controller.addListener(() {
      if (mounted) {
        setState(() {
          _position = widget.controller.value.position;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
            child: _isInitialized
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: widget.controller.value.aspectRatio,
                        child: VideoPlayer(widget.controller),
                      ),
                      Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) async {
                          final newPosition = Duration(seconds: value.toInt());
                          await widget.controller.seekTo(newPosition);
                          setState(() {
                            _position = newPosition;
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10),
                            onPressed: () async {
                              final newPosition =
                                  _position - const Duration(seconds: 10);
                              await widget.controller.seekTo(
                                  newPosition > Duration.zero
                                      ? newPosition
                                      : Duration.zero);
                              setState(() {
                                _position = newPosition > Duration.zero
                                    ? newPosition
                                    : Duration.zero;
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(widget.controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                            onPressed: () {
                              setState(() {
                                if (widget.controller.value.isPlaying) {
                                  widget.controller.pause();
                                } else {
                                  widget.controller.play();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10),
                            onPressed: () async {
                              final newPosition =
                                  _position + const Duration(seconds: 10);
                              await widget.controller.seekTo(
                                  newPosition < _duration
                                      ? newPosition
                                      : _duration);
                              setState(() {
                                _position = newPosition < _duration
                                    ? newPosition
                                    : _duration;
                              });
                            },
                          ),
                        ],
                      ),
                      Text(
                        '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / '
                        '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {});
    widget.controller.pause();
    widget.controller.dispose();
    super.dispose();
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final String fileName;

  const WebViewPage({super.key, required this.url, required this.fileName});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://docs.google.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _controller.runJavaScript('''
              document.oncontextmenu = function() { return false; };
              document.querySelectorAll('a[download]').forEach(e => e.removeAttribute('download'));
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Failed to load document: ${error.description}')),
              );
            }
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)).catchError((e) {
        if (kDebugMode) print('WebView load error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading document: $e')),
          );
        }
        setState(() => _isLoading = false);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fileName)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class WindowsWebViewPage extends StatefulWidget {
  final String url;
  final String fileName;
  final bool? isVideo;
  final bool isAdmin;

  const WindowsWebViewPage({
    super.key,
    required this.url,
    required this.fileName,
    this.isVideo,
    required this.isAdmin,
  });

  @override
  _WindowsWebViewPageState createState() => _WindowsWebViewPageState();
}

class _WindowsWebViewPageState extends State<WindowsWebViewPage> {
  final _controller = webview_windows.WebviewController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      await _controller.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('WebView initialization timed out');
        },
      );
      await _controller.setJavaScriptEnabled(true);
      await _controller
          .setPopupWindowPolicy(webview_windows.WebviewPopupWindowPolicy.deny);
      if (widget.isVideo == true) {
        await _controller.loadStringContent('''
          <!DOCTYPE html>
          <html>
          <body style="margin:0;background:black;">
            <video id="videoPlayer" src="${widget.url}" controls controlsList="nodownload" disablePictureInPicture
                   style="width:100%;height:100vh;object-fit:contain;" autoplay>
            </video>
            <script>
              var video = document.getElementById('videoPlayer');
              video.play();
              document.oncontextmenu = function() { return false; };
              function seekBackward() {
                video.currentTime = Math.max(0, video.currentTime - 10);
              }
              function seekForward() {
                video.currentTime = Math.min(video.duration, video.currentTime + 10);
              }
            </script>
          </body>
          </html>
        ''');
      } else {
        await _controller.loadUrl(widget.url);
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (kDebugMode) print('Windows WebView error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: widget.isVideo == true
            ? [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () async {
                    try {
                      await _controller.executeScript('seekBackward();');
                    } catch (e) {
                      if (kDebugMode) print('Seek backward error: $e');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () async {
                    try {
                      await _controller.executeScript('seekForward();');
                    } catch (e) {
                      if (kDebugMode) print('Seek forward error: $e');
                    }
                  },
                ),
              ]
            : null,
      ),
      body: _isInitialized && _controller.value.isInitialized
          ? webview_windows.Webview(_controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

extension on webview_windows.WebviewController {
  Future<void> setJavaScriptEnabled(bool enabled) async {
    await executeScript('window.alert = function() {};');
  }
}
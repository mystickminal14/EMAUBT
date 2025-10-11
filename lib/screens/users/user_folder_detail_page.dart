import 'dart:async';
import 'dart:io';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/users/downloadcontent_page.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:ema_app/view_model/user_view_model/user_folder_view_model.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as webview_windows;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:logger/logger.dart';

import '../../../model/user_model.dart';

class UserFolderDetailsPage extends StatefulWidget {
  final String folderId, userId, userName, role;
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
    required this.userName,
    required this.role,
    required this.userId,
  });

  @override
  _UserFolderDetailsPageState createState() => _UserFolderDetailsPageState();
}

class _UserFolderDetailsPageState extends State<UserFolderDetailsPage> {
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _cachedFullName;
  String? _cachedProfileImage;
  String? _cachedUserEmail;
  final Dio _dio = Dio();
  late UserFolderViewModel _viewModel;
  final Logger _logger = Logger();

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
          padding: screenWidth * 0.05,
          titleFontSize: orientation == Orientation.portrait ? 20.0 : 18.0,
          itemWidth: screenWidth * 0.92,
          itemHeight: orientation == Orientation.portrait ? 80.0 : 90.0,
          itemFontSize: orientation == Orientation.portrait ? 16.0 : 14.0,
          iconSize: 30.0,
          crossAxisCount: 1,
        );
      case ScreenSize.medium:
        return ResponsiveDimensions(
          padding: screenWidth * 0.04,
          titleFontSize: orientation == Orientation.portrait ? 22.0 : 20.0,
          itemWidth: screenWidth * 0.85,
          itemHeight: orientation == Orientation.portrait ? 90.0 : 100.0,
          itemFontSize: orientation == Orientation.portrait ? 16.0 : 15.0,
          iconSize: 32.0,
          crossAxisCount: 1,
        );
      case ScreenSize.large:
        return ResponsiveDimensions(
          padding: 32.0,
          titleFontSize: orientation == Orientation.portrait ? 26.0 : 24.0,
          itemWidth: orientation == Orientation.portrait ? 450.0 : screenWidth * 0.45,
          itemHeight: orientation == Orientation.portrait ? 80.0 : 90.0,
          itemFontSize: orientation == Orientation.portrait ? 18.0 : 16.0,
          iconSize: 36.0,
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
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'odt', 'ods', 'odp'].contains(extension)) {
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
    _viewModel = UserFolderViewModel();
    _viewModel.addListener(() {
      if (mounted) setState(() {});
    });
    _initUserInfo();
    _loadData();
  }

  Future<void> _initUserInfo() async {
    final userViewModel = UserViewModel();
    UserModel? user = await userViewModel.getUser();

    if (widget.fullName != null || widget.profileImage != null || widget.userEmail != null) {
      user = UserModel(
        email: widget.userEmail ?? user?.email ?? '',
        name: widget.fullName ?? user?.name ?? '',
        role: user?.role ?? '',
        image: widget.profileImage ?? user?.image ?? '',
        success: true,
      );
      await userViewModel.saveUser(user);
    }

    user = await userViewModel.getUser();
    var logg=Logger();
    logg.d(user?.email);
    if (user != null && mounted) {
      setState(() {
        _cachedFullName = user?.fullName ?? '';
        _cachedProfileImage = user?.image ?? '';
        _cachedUserEmail = user?.email ?? '';
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var logs=Logger();
      logs.d(widget.userIdentifier);
      await _viewModel.fetchFiles(widget.folderId, widget.isAdmin, widget.userIdentifier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      _logger.e('Error fetching files: $e');
    }

    try {
      await _viewModel.fetchQuizSets(widget.folderId, widget.isAdmin, widget.userIdentifier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      _logger.e('Error fetching quiz sets: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildItemIcon(Map<String, dynamic> item, IconData defaultIcon) {
    if (item['icon_path'] != null && item['icon_path'].isNotEmpty) {
      return Image.network(
        '${BaseUrl.baseUrl}/${item['icon_path']}',
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(defaultIcon, size: 32, color: Theme.of(context).primaryColor),
      );
    }
    return Icon(defaultIcon, size: 32, color: Theme.of(context).primaryColor);
  }

  void _showAccessDetailsDialog(Map<String, dynamic> item, String itemType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Access Details for ${item['name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAdmin
                  ? 'Access: Unlimited (Admin)'
                  : item['has_permission'] == true
                  ? (item['access_times'] == -1
                  ? 'Access: Unlimited'
                  : 'Access: ${item['access_times']} times')
                  : 'Access: Contact Admin',
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
            ),
            if (item['has_permission'] == true) ...[
              const SizedBox(height: 8),
              Text(
                'Times Accessed: ${item['times_accessed']}',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              ),
              if (item['is_active'] == 0)
                const Text(
                  'Status: Not activated by admin',
                  style: TextStyle(color: Colors.redAccent),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.teal)),
          ),
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
              if (mounted) {
                setDialogState(() => isPlaying = state == PlayerState.playing);
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(fileName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAudioLoading)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading Audio...', style: TextStyle(fontSize: 14)),
                        ],
                      )
                    else ...[
                      Text('Position: ${position.inSeconds} s', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      Text(
                        'State: ${isPlaying ? "Playing" : "Paused/Stopped"}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildAudioButton(
                            context,
                            'Play',
                            Icons.play_arrow,
                                () async {
                              await _audioPlayer.play(
                                kIsWeb ? UrlSource(url) : DeviceFileSource(localFilePath!),
                              );
                              setDialogState(() => isPlaying = true);
                            },
                          ),
                          _buildAudioButton(
                            context,
                            'Pause',
                            Icons.pause,
                                () async {
                              await _audioPlayer.pause();
                              setDialogState(() => isPlaying = false);
                            },
                          ),
                          _buildAudioButton(
                            context,
                            'Stop',
                            Icons.stop,
                                () async {
                              await _audioPlayer.stop();
                              setDialogState(() {
                                isPlaying = false;
                                position = Duration.zero;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildAudioButton(
                            context,
                            '← 10s',
                            Icons.replay_10,
                                () async {
                              final currentPosition = await _audioPlayer.getCurrentPosition();
                              if (currentPosition != null) {
                                final newPosition = currentPosition - const Duration(seconds: 10);
                                await _audioPlayer.seek(
                                    newPosition > Duration.zero ? newPosition : Duration.zero);
                                setDialogState(() => position =
                                newPosition > Duration.zero ? newPosition : Duration.zero);
                              }
                            },
                          ),
                          _buildAudioButton(
                            context,
                            '10s →',
                            Icons.forward_10,
                                () async {
                              final currentPosition = await _audioPlayer.getCurrentPosition();
                              if (currentPosition != null && totalDuration != null) {
                                final newPosition = currentPosition + const Duration(seconds: 10);
                                await _audioPlayer.seek(
                                    newPosition < totalDuration! ? newPosition : totalDuration!);
                                setDialogState(() => position =
                                newPosition < totalDuration! ? newPosition : totalDuration!);
                              }
                            },
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
                      _logger.e('Error during cleanup: $e');
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Close', style: TextStyle(color: Colors.teal)),
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
            _logger.e('Error deleting file: $e');
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
      _logger.e('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error playing audio: $e')));
        Navigator.pop(context);
      }
    }
  }

  Widget _buildAudioButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showImageViewer(String url, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: CachedNetworkImage(
          imageUrl: url,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error, size: 48),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.teal)),
          ),
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
          _logger.e('Video init error on Android: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error initializing video: $e')),
            );
          }
          await controller.dispose();
        }
      }
    } catch (e) {
      _logger.e('Video setup error on Android: $e');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Access Denied', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file['has_permission'] == true
                    ? 'This file is not activated by admin.'
                    : 'This file requires admin activation.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _makePhoneCall('+9779851213520', context),
                child: const Text(
                  'Phone: +9779851213520',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openFacebook(context),
                child: const Text(
                  'Facebook: yogendra.wagle.12',
                  style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.teal)),
            ),
          ],
        ),
      );
      return;
    }

    if (file['file_path'] == null) {
      final fetchedFilePath = await _viewModel.fetchFilePath(file['id']);
      if (fetchedFilePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load file: File path not found')),
          );
        }
        return;
      }
      file['file_path'] = fetchedFilePath;
    }

    if (!widget.isAdmin && widget.userIdentifier.isNotEmpty) {
      bool incremented = await _viewModel.incrementAccessCount(
          file['id'], 'file', widget.isAdmin, widget.userIdentifier);
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

    final fileUrl = '${BaseUrl.baseUrl}${file['file_path']}';
    final encodedFileUrl = Uri.encodeFull(fileUrl);
    final viewerUrl =
        'https://docs.google.com/viewer?url=$encodedFileUrl&embedded=true&_cache_bust=${DateTime.now().millisecondsSinceEpoch}';
    final fileType = _getFileType(file['name'] ?? '');
    if (kDebugMode) {
      _logger.i('File: ${file['name']}, Type: $fileType, URL: $fileUrl');
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
      _logger.e('Failed to open Facebook: $e');
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
            const SnackBar(content: Text('No app available to make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to make phone call: $e')),
        );
      }
      _logger.e('Failed to make phone call: $e');
    }
  }

  Widget _buildItemTile(
      ResponsiveDimensions dimensions,
      Map<String, dynamic> item,
      String itemType,
      VoidCallback onTap,
      ) {
    final canAccess = item['can_access'] == true;
    final isActive = item['is_active'] == 1;
    final fileType = itemType == 'file' ? _getFileType(item['name'] ?? '') : null;

    if (kDebugMode) {
      _logger.i('Building Tile for Item: ${item['name']}, can_access: $canAccess, is_active: $isActive');
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Container(
          width: dimensions.itemWidth,
          height: dimensions.itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _buildItemIcon(item, itemType == 'file' ? Icons.insert_drive_file : Icons.quiz),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['name'] ?? (itemType == 'file' ? 'Unnamed File' : 'Unnamed Quiz Set'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      maxLines: null, // ✅ allow unlimited lines
                      overflow: TextOverflow.visible, // ✅ show full text
                    ),

                    const SizedBox(height: 1),
                    Text(
                      itemType == 'file' ? fileType?.toUpperCase() ?? 'FILE' : 'QUIZ',
                      style: TextStyle(
                        fontSize: dimensions.itemFontSize * 0.8,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              canAccess
                  ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  itemType == 'quiz_set' || fileType == 'pdf' || fileType == 'office' || fileType == 'image'
                      ? 'Open'
                      : 'Play',
                  style: TextStyle(fontSize: dimensions.itemFontSize * 0.8),
                ),
              )
                  : Text(
                'Contact Admin',
                style: TextStyle(
                  fontSize: dimensions.itemFontSize * 0.8,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              IconButton(
                icon: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                iconSize: dimensions.iconSize * 0.8,
                onPressed: () => _showAccessDetailsDialog(item, itemType),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveItemGrid(
      BuildContext context,
      ResponsiveDimensions dimensions,
      List<Map<String, dynamic>> items,
      String itemType,
      ) {
    return ListView.builder(
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Access Denied', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['has_permission'] == true
                            ? 'This quiz set is not activated by admin.'
                            : 'This quiz set requires admin activation.',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _makePhoneCall('+9779851213520', context),
                        child: const Text(
                          'Phone: +9779851213520',
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _openFacebook(context),
                        child: const Text(
                          'Facebook: yogendra.wagle.12',
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Colors.teal)),
                    ),
                  ],
                ),
              );
              return;
            }

            if (!widget.isAdmin && widget.userIdentifier.isNotEmpty) {
              bool incremented = await _viewModel.incrementAccessCount(
                  item['id'], 'quiz_set', widget.isAdmin, widget.userIdentifier);
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
                  userIdentifier: widget.userIdentifier.isEmpty ? 'guest' : widget.userIdentifier,
                  isAdmin: widget.isAdmin,
                  fullName: _cachedFullName ?? '',
                  userEmail: widget.isAdmin ? widget.userIdentifier : _cachedUserEmail ?? '',
                  folderId: widget.folderId,
                  folderName: widget.folderName,
                  userId: '',
                  userName: '',
                  role: '',
                ),
              ),
            ).then((_) => _loadData());
          } else {
            _handleFileTap(item);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _getResponsiveDimensions(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Theme(
      data: ThemeData(
        primaryColor: Colors.teal[700],
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardThemeData(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pop(context); // Go back to the previous page
            },
          ),
          title: Text(
            widget.folderName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          backgroundColor: Colors.teal[700],
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[700]!, Colors.teal[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white, size: 28),
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

        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(dimensions.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    if (_viewModel.quizSets.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          "Quiz Sets",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      _buildResponsiveItemGrid(context, dimensions, _viewModel.quizSets, 'quiz_set'),
                      Divider(color: Colors.teal[200], thickness: 1),
                    ],
                    if (_viewModel.files.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          "Files",
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      _buildResponsiveItemGrid(context, dimensions, _viewModel.files, 'file'),
                      Divider(color: Colors.teal[200], thickness: 1),
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
    _viewModel.removeListener(() {});
    _viewModel.dispose();
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
  final Logger _logger = Logger();

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
        if (kDebugMode) _logger.e('Video init error on Android: $e');
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
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
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
                  activeColor: Colors.teal[700],
                  inactiveColor: Colors.teal[100],
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
                      icon: const Icon(Icons.replay_10, color: Colors.teal),
                      onPressed: () async {
                        final newPosition = _position - const Duration(seconds: 10);
                        await widget.controller.seekTo(
                            newPosition > Duration.zero ? newPosition : Duration.zero);
                        setState(() {
                          _position = newPosition > Duration.zero ? newPosition : Duration.zero;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.teal,
                      ),
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
                      icon: const Icon(Icons.forward_10, color: Colors.teal),
                      onPressed: () async {
                        final newPosition = _position + const Duration(seconds: 10);
                        await widget.controller.seekTo(
                            newPosition < _duration ? newPosition : _duration);
                        setState(() {
                          _position = newPosition < _duration ? newPosition : _duration;
                        });
                      },
                    ),
                  ],
                ),
                Text(
                  '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / '
                      '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.black87),
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
  final Logger _logger = Logger();

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
                SnackBar(content: Text('Failed to load document: ${error.description}')),
              );
            }
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url)).catchError((e) {
        if (kDebugMode) _logger.e('WebView load error: $e');
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
      appBar: AppBar(
        title: Text(widget.fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
      ),
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
  final Logger _logger = Logger();

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
      await _controller.setPopupWindowPolicy(webview_windows.WebviewPopupWindowPolicy.deny);
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
      if (kDebugMode) _logger.e('Windows WebView error: $e');
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
        title: Text(widget.fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: widget.isVideo == true
            ? [
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white),
            onPressed: () async {
              try {
                await _controller.executeScript('seekBackward();');
              } catch (e) {
                if (kDebugMode) _logger.e('Seek backward error: $e');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.forward_10, color: Colors.white),
            onPressed: () async {
              try {
                await _controller.executeScript('seekForward();');
              } catch (e) {
                if (kDebugMode) _logger.e('Seek forward error: $e');
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
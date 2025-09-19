import 'dart:io';

import 'package:ema_app/screens/users/user_quiz_sets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginUserFreeFilesQuizSets extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const LoginUserFreeFilesQuizSets({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
  });

  @override
  _LoginUserFreeFilesQuizSetsState createState() =>
      _LoginUserFreeFilesQuizSetsState();
}

class _LoginUserFreeFilesQuizSetsState
    extends State<LoginUserFreeFilesQuizSets> {
  List<Map<String, dynamic>> folders = [];
  bool _isLoading = true;
  String? _errorMessage;
  late SharedPreferences _prefs;
  String? _cachedFullName;
  String? _cachedUserEmail;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _fetchFolders();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedFullName = _prefs.getString('fullName') ?? '';
      _cachedUserEmail = _prefs.getString('userEmail') ?? widget.userIdentifier;
    });
  }

  Future<void> _fetchFolders() async {
    try {
      final response =
          await http.get(Uri.parse("https://theemaeducation.com/folders.php"));
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedFolders =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        setState(() {
          folders = fetchedFolders.map((folder) {
            return {
              "id": int.tryParse(folder["id"].toString()) ?? 0,
              "name": folder["name"],
              "icon_path": folder["icon_path"],
            };
          }).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to load folders: Server error (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading folders: $e";
      });
    }
  }

  void _openFolder(int folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeForLoginPage(
          folderId: folderId,
          folderName: folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: _cachedFullName,
          userEmail: _cachedUserEmail,
        ),
      ),
    );
  }

  Widget _buildFolderCard(Map<String, dynamic> folder) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: folder["icon_path"] != null
              ? Image.network(
                  "https://theemaeducation.com/${folder["icon_path"]}",
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.folder,
                        size: 48, color: Colors.teal);
                  },
                )
              : const Icon(Icons.folder, size: 48, color: Colors.teal),
        ),
        title: Text(
          folder["name"],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => _openFolder(folder["id"], folder["name"]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Free Files & Quiz Sets"),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_errorMessage!,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchFolders,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : folders.isEmpty
                      ? const Center(
                          child: Text("No folders available",
                              style: TextStyle(fontSize: 18)))
                      : ListView.builder(
                          itemCount: folders.length,
                          itemBuilder: (context, index) =>
                              _buildFolderCard(folders[index]),
                        ),
        ),
      ),
    );
  }
}

class FreeForLoginPage extends StatefulWidget {
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const FreeForLoginPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  _FreeForLoginPageState createState() => _FreeForLoginPageState();
}

class _FreeForLoginPageState extends State<FreeForLoginPage> {
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];
  bool _isLoading = true;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final response = await http.get(Uri.parse(
          'https://theemaeducation.com/give_access_to_login_users.php?action=get_granted_access_items&folder_id=${widget.folderId}'));
      final decodedResponse = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          decodedResponse['status'] == 'success') {
        final items = List<Map<String, dynamic>>.from(decodedResponse['data'])
            .map((item) => {
                  ...item,
                  'id': int.parse(item['id'].toString()),
                  'item_type': item['item_type'],
                })
            .toList();

        setState(() {
          files = items.where((item) => item['item_type'] == 'file').toList();
          quizSets =
              items.where((item) => item['item_type'] == 'quiz_set').toList();
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Failed to fetch items: ${decodedResponse['message']}";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error fetching items: $e";
      });
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (['mp3', 'wav', 'm4a'].contains(extension)) return 'audio';
    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) return 'image';
    if (['mp4', 'avi', 'mkv', 'mov'].contains(extension)) return 'video';
    if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) return 'document';
    return 'other';
  }

  Future<void> _openExternalFile(String url, String fileName) async {
    if (kIsWeb) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $fileName')),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      await _dio.download(url, filePath);

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open $fileName: ${result.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $fileName: $e')),
      );
    }
  }

  Future<void> _showAudioPlayer(String url, String fileName) async {
    await _audioPlayer.stop();
    await _audioPlayer.release();

    String filePath;
    if (kIsWeb) {
      filePath = url;
    } else {
      final tempDir = await getTemporaryDirectory();
      filePath = '${tempDir.path}/$fileName';
      try {
        await _dio.download(url, filePath);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading audio: $e')),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration?>(
              stream: _audioPlayer.onPositionChanged,
              builder: (context, snapshot) {
                final position = snapshot.data?.inSeconds ?? 0;
                return Text('Position: $position s');
              },
            ),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.onPlayerStateChanged,
              builder: (context, snapshot) {
                final state = snapshot.data ?? PlayerState.stopped;
                return Text('Player State: $state');
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _audioPlayer.play(kIsWeb
                          ? UrlSource(filePath)
                          : DeviceFileSource(filePath));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error playing audio: $e')),
                      );
                    }
                  },
                  child: const Text('Play'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _audioPlayer.pause();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error pausing audio: $e')),
                      );
                    }
                  },
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _audioPlayer.stop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error stopping audio: $e')),
                      );
                    }
                  },
                  child: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _audioPlayer.stop();
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFileTap(Map<String, dynamic> file) async {
    final fileUrl = 'https://theemaeducation.com/${file['file_path']}';
    final fileName = file['name'].toString();
    final fileType = _getFileType(fileName);

    if (fileType == 'document') {
      try {
        // Download the file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await _dio.download(fileUrl, tempFile.path);

        if (fileName.toLowerCase().endsWith('.pdf')) {
          // Open PDF in-app
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PDFViewerPage(filePath: tempFile.path, fileName: fileName),
            ),
          );
        } else if (fileName.toLowerCase().endsWith('.txt')) {
          // Open TXT in-app
          final content = await tempFile.readAsString();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TextViewerPage(content: content, fileName: fileName),
            ),
          );
        } else {
          // Fallback for other documents (e.g., DOCX)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Cannot open $fileName in-app, downloading...')),
          );
          await _openExternalFile(fileUrl, fileName);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error opening $fileName: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } else {
      // Handle non-document files (audio, image, video, other)
      switch (fileType) {
        case 'audio':
          await _showAudioPlayer(fileUrl, fileName);
          break;
        case 'image':
          _showImageViewer(fileUrl, fileName);
          break;
        case 'video':
        case 'other':
        default:
          await _openExternalFile(fileUrl, fileName);
          break;
      }
    }
  }
  

  Widget _buildItemIcon(Map<String, dynamic> item, IconData defaultIcon) {
    if (item['icon_path'] != null && item['icon_path'].isNotEmpty) {
      return Image.network(
        'https://theemaeducation.com/${item['icon_path']}',
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(defaultIcon, size: 40, color: Colors.grey);
        },
      );
    }
    return Icon(defaultIcon, size: 40, color: Colors.grey);
  }

  Widget _buildItemTile(
      Map<String, dynamic> item, String itemType, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildItemIcon(item,
                  itemType == 'file' ? Icons.insert_drive_file : Icons.quiz),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ??
                          (itemType == 'file'
                              ? 'Unnamed File'
                              : 'Unnamed Quiz Set'),
                      style: const TextStyle(fontSize: 20),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Can Use',
                        style: TextStyle(color: Colors.green, fontSize: 20),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(_errorMessage!,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchContent,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : (files.isEmpty && quizSets.isEmpty)
                      ? const Center(
                          child: Text("No content available",
                              style: TextStyle(fontSize: 18)))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (files.isNotEmpty) ...[
                                const Text(
                                  "Files (Can Use)",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: files.length,
                                  itemBuilder: (context, index) {
                                    final file = files[index];
                                    return _buildItemTile(
                                      file,
                                      'file',
                                      () => _handleFileTap(file),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (quizSets.isNotEmpty) ...[
                                const Text(
                                  "Quiz Sets (Can Use)",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: quizSets.length,
                                  itemBuilder: (context, index) {
                                    final quizSet = quizSets[index];
                                    return _buildItemTile(
                                      quizSet,
                                      'quiz_set',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                UserQuizSetsPage(
                                              quizSetId: quizSet['id'],
                                              quizSetName: quizSet['name'],
                                              userId: widget.isAdmin
                                                  ? ''
                                                  : widget.userIdentifier
                                                          .isEmpty
                                                      ? 'guest'
                                                      : widget.userIdentifier,
                                              userName: widget.fullName ?? '',
                                              userEmail: widget.isAdmin
                                                  ? widget.userIdentifier
                                                  : widget.userEmail ??
                                                      widget.userIdentifier,
                                              role: widget.isAdmin
                                                  ? 'admin'
                                                  : 'user',
                                              folderId: widget.folderId,
                                              folderName: widget.folderName,
                                              isAdmin: widget.isAdmin,
                                              userIdentifier:
                                                  widget.userIdentifier,
                                              preStart: true, cachedFiles: {}, quizData: {},
                                            ),
                                          ),
                                        ).then((_) => _fetchContent());
                                      },
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

// PDF Viewer Page
class PDFViewerPage extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PDFViewerPage(
      {super.key, required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: Colors.teal,
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error loading PDF: $error'),
                backgroundColor: Colors.redAccent),
          );
        },
      ),
    );
  }
}

// Text Viewer Page
class TextViewerPage extends StatelessWidget {
  final String content;
  final String fileName;

  const TextViewerPage(
      {super.key, required this.content, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}


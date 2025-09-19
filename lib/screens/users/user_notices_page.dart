import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class UserNoticesPage extends StatefulWidget {
  const UserNoticesPage({super.key});

  @override
  _UserNoticesPageState createState() => _UserNoticesPageState();
}

class _UserNoticesPageState extends State<UserNoticesPage> {
  List<Notice> notices = [];
  final String apiUrl = 'https://theemaeducation.com/notices.php';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  Future<void> _fetchNotices() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          notices = data.map((json) => Notice.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching notices: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching notices: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Important Information",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.deepPurple[700],
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple[700]!),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading notices...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : notices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No Important Information available",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: notices.length,
                  itemBuilder: (context, index) {
                    return UserNoticeWidget(notice: notices[index]);
                  },
                ),
    );
  }
}

class Notice {
  final String id;
  final String title;
  final String? textContent;
  final List<dynamic> files;

  Notice({
    required this.id,
    required this.title,
    this.textContent,
    required this.files,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'],
      title: json['title'],
      textContent: json['text_content'],
      files: json['files'] as List<dynamic>? ?? [],
    );
  }
}

class UserNoticeWidget extends StatelessWidget {
  final Notice notice;

  const UserNoticeWidget({super.key, required this.notice});

  Future<void> _openFile(BuildContext context, dynamic file) async {
    if (file['file_path'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path is missing')),
      );
      return;
    }

    final String fileName = file['file_name'].toLowerCase();
    String filePath = file['file_path'];

    // Normalize file path
    filePath = path.normalize(filePath);
    
    // Ensure proper file URI format
    final File fileObject = File(filePath);
    
    if (!await fileObject.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File does not exist at: $filePath')),
      );
      return;
    }

    try {
      if (fileName.endsWith('.jpg') || 
          fileName.endsWith('.jpeg') || 
          fileName.endsWith('.png')) {
        // Show images in app for all platforms
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(filePath: filePath),
          ),
        );
      } else if (Platform.isWindows) {
        // For non-image files on Windows
        final Uri fileUri = Uri.parse('file:///$filePath');
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          throw 'Could not launch $fileUri';
        }
      } else {
        // For non-image files on mobile
        final Uri fileUri = Uri.file(filePath);
        if (await canLaunchUrl(fileUri)) {
          await launchUrl(fileUri);
        } else {
          throw 'Could not launch $fileUri';
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.deepPurple[800],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12.0),
            if (notice.textContent != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  notice.textContent!,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
            ],
            if (notice.files.isNotEmpty) ...[
              Text(
                'Attachments',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8.0),
              ...notice.files.map((file) => InkWell(
                    onTap: () => _openFile(context, file),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 12.0,
                      ),
                      margin: const EdgeInsets.only(bottom: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getFileIcon(file['file_name']),
                            size: 24,
                            color: Colors.deepPurple[600],
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              file['file_name'],
                              style: TextStyle(
                                color: Colors.deepPurple[700],
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String filePath;
  const ImageViewerScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'View Image',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.black87,
        child: Center(
          child: FutureBuilder<bool>(
            future: File(filePath).exists(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple[700]!),
                );
              }
              if (snapshot.hasData && snapshot.data == true) {
                return InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20.0),
                  minScale: 0.1,
                  maxScale: 4.0,
                  child: Image.file(
                    File(filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error loading image',
                          style: TextStyle(
                            color: Colors.red[300],
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Image file not found',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: const UserNoticesPage(),
    theme: ThemeData(
      primarySwatch: Colors.deepPurple,
      cardTheme: CardThemeData(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 15.0),
      ),
    ),
  ));
}
import 'package:ema_app/view_model/folders/notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class UserNoticesPage extends StatefulWidget {
  const UserNoticesPage({super.key});

  @override
  State<UserNoticesPage> createState() => _UserNoticesPageState();
}

class _UserNoticesPageState extends State<UserNoticesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NoticeManagementViewModel>(context, listen: false)
            .fetchNotices(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoticeManagementViewModel>(
      builder: (context, noticeVM, _) {
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
          body: noticeVM.isLoading
              ? _buildLoading()
              : noticeVM.filteredNotices.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: noticeVM.filteredNotices.length,
                      itemBuilder: (context, index) {
                        return UserNoticeWidget(
                          notice: noticeVM.filteredNotices[index],
                        );
                      },
                    ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
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
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
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
    );
  }
}

class UserNoticeWidget extends StatelessWidget {
  final dynamic notice; // using NoticeModel

  const UserNoticeWidget({super.key, required this.notice});

  Future<void> _openFile(BuildContext context, dynamic file) async {
    if (file.filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path is missing')),
      );
      return;
    }

    final String fileName = file.fileName.toLowerCase();
    String filePath = path.normalize(file.filePath);
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageViewerScreen(filePath: filePath),
          ),
        );
      } else {
        final Uri fileUri = Platform.isWindows
            ? Uri.parse('file:///$filePath')
            : Uri.file(filePath);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.title ?? '',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.deepPurple[800],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12.0),
            if (notice.textContent != null &&
                notice.textContent!.isNotEmpty) ...[
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
            if (notice.files != null && notice.files!.isNotEmpty) ...[
              Text(
                'Attachments',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8.0),
              ...notice.files!.map((file) => InkWell(
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
                            _getFileIcon(file.fileName),
                            size: 24,
                            color: Colors.deepPurple[600],
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Text(
                              file.fileName,
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
          style: TextStyle(fontWeight: FontWeight.w600),
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.deepPurple[700]!),
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
                  ),
                );
              }
              return const Text(
                'Image file not found',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              );
            },
          ),
        ),
      ),
    );
  }
}

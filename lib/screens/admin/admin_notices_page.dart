import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // For opening files in browser
import 'package:flutter/foundation.dart' show Uint8List; // To check if running on web

void main() {
  runApp(const MaterialApp(home: NoticesPage()));
}

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  _NoticesPageState createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<Notice> notices = [];
  final String apiUrl = 'https://theemaeducation.com/notices.php';

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
        });
      } else {
        print('Error fetching notices: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch notices')),
        );
      }
    } catch (e) {
      print('Error fetching notices: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching notices: $e')),
      );
    }
  }

  void _showAddDialog() {
    _showNoticeDialog(context, isEdit: false);
  }

  void _showEditDialog(Notice notice) {
    _showNoticeDialog(context, isEdit: true, existingNotice: notice);
  }

  Future<void> _deleteNotice(Notice notice) async {
    try {
      final url = Uri.parse('$apiUrl?id=${Uri.encodeQueryComponent(notice.id)}');
      print('Sending DELETE request to: $url');
      final response = await http.delete(url, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Request to $url timed out');
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await _fetchNotices();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notice deleted successfully')),
          );
        } else {
          print('Error deleting notice: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete notice: ${data['error'] ?? 'Unknown error'}')),
          );
        }
      } else {
        print('Error deleting notice: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notice: HTTP ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error deleting notice: $e');
      String errorMessage = 'Error deleting notice';
      if (e is TimeoutException) {
        errorMessage = 'Request timed out. Please check your network connection.';
      } else if (e is SocketException) {
        errorMessage = 'Network error. Please check your internet connection or server availability.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: $e')),
      );
    }
  }

  Future<void> _showNoticeDialog(BuildContext context, {bool isEdit = false, Notice? existingNotice}) async {
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final textController = TextEditingController(text: existingNotice?.textContent ?? '');
    List<PlatformFile> files = List.from(existingNotice?.files ?? []);
    final fileNameControllers = files.map((file) => TextEditingController(text: file.name)).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Important Information' : 'Add Important Information'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: textController, decoration: const InputDecoration(labelText: 'Text Content')),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
                    if (result != null) {
                      setDialogState(() {
                        files = result.files.map((file) => PlatformFile(
                          name: file.name,
                          path: file.path,
                          size: file.size,
                          bytes: file.bytes,
                          url: null,
                        )).toList();
                        fileNameControllers.clear();
                        fileNameControllers.addAll(files.map((file) => TextEditingController(text: file.name)));
                      });
                    }
                  },
                  child: Text(files.isNotEmpty ? 'Change Files' : 'Pick Files'),
                ),
                if (files.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...List.generate(files.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: fileNameControllers[index],
                        decoration: InputDecoration(labelText: 'File Name ${index + 1}'),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Title is required')),
                  );
                  return;
                }

                final updatedFiles = List.generate(files.length, (index) {
                  return PlatformFile(
                    name: fileNameControllers[index].text.isEmpty ? files[index].name : fileNameControllers[index].text,
                    path: files[index].path,
                    size: files[index].size,
                    bytes: files[index].bytes,
                    url: files[index].url,
                  );
                });

                final newNotice = Notice(
                  id: isEdit ? existingNotice!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text,
                  textContent: textController.text.isEmpty ? null : textController.text,
                  files: updatedFiles,
                );

                try {
                  final url = Uri.parse(apiUrl);
                  final body = json.encode({
                    'id': newNotice.id,
                    'title': newNotice.title,
                    'text_content': newNotice.textContent,
                    'files': newNotice.files.map((file) => {
                      'name': file.name,
                      'path': file.url ?? file.path ?? '',
                    }).toList(),
                  });

                  print('Sending ${isEdit ? 'PUT' : 'POST'} request to: $url with body: $body');
                  final response = await (isEdit
                      ? http.put(url, body: body, headers: {'Content-Type': 'application/json'})
                      : http.post(url, body: body, headers: {'Content-Type': 'application/json'}));

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    if (data['success'] == true) {
                      await _fetchNotices();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEdit ? 'Important Information updated successfully' : 'Important Information added successfully')),
                      );
                    } else {
                      print('Error ${isEdit ? 'updating' : 'adding'} notice: ${response.body}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to ${isEdit ? 'update' : 'add'} notice')),
                      );
                    }
                  } else {
                    print('Error ${isEdit ? 'updating' : 'adding'} notice: ${response.statusCode} - ${response.body}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to ${isEdit ? 'update' : 'add'} notice')),
                    );
                  }
                } catch (e) {
                  print('Error ${isEdit ? 'updating' : 'adding'} notice: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error ${isEdit ? 'updating' : 'adding'} notice: $e')),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Important Information")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: notices.length,
        itemBuilder: (context, index) {
          return NoticeWidget(
            notice: notices[index],
            onEdit: () => _showEditDialog(notices[index]),
            onDelete: () => _deleteNotice(notices[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlatformFile {
  final String name;
  final String? path;
  final int size;
  final Uint8List? bytes;
  final String? url;

  PlatformFile({
    required this.name,
    this.path,
    required this.size,
    this.bytes,
    this.url,
  });
}

class Notice {
  final String id;
  final String title;
  final String? textContent;
  final List<PlatformFile> files;

  Notice({
    required this.id,
    required this.title,
    this.textContent,
    this.files = const [],
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'].toString(),
      title: json['title'],
      textContent: json['text_content'],
      files: (json['files'] as List<dynamic>?)?.map((file) => PlatformFile(
        name: file['file_name'],
        path: null, // Server does not provide local path
        size: 0,
        url: 'https://theemaeducation.com/${file['file_path']}',
      )).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text_content': textContent,
    'files': files.map((file) => {
      'name': file.name,
      'path': file.url ?? file.path ?? '',
    }).toList(),
  };
}

class NoticeWidget extends StatelessWidget {
  final Notice notice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const NoticeWidget({
    super.key,
    required this.notice,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _openFile(BuildContext context, PlatformFile file) async {
    if (file.url != null) {
      final uri = Uri.parse(file.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch ${file.url}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${file.name}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No URL available for file: ${file.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    notice.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (notice.textContent != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  notice.textContent!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8.0),
            ],
            if (notice.files.isNotEmpty) ...[
              ...notice.files.map((file) {
                final isImage = file.name.toLowerCase().endsWith('.jpg') ||
                    file.name.toLowerCase().endsWith('.jpeg') ||
                    file.name.toLowerCase().endsWith('.png');

                return GestureDetector(
                  onTap: () => _openFile(context, file),
                  child: Column(
                    children: [
                      if (isImage && file.url != null) ...[
                        Image.network(
                          file.url!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Text(
                            "Failed to load image",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file, size: 20),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8.0),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
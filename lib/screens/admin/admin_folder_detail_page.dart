import 'dart:io';
import 'package:ema_app/model/files_model.dart';
import 'package:ema_app/model/files_model.dart';
import 'package:ema_app/model/quiz_set_model.dart';
import 'package:ema_app/view_model/folders/files_view_model.dart';
import 'package:ema_app/view_model/folders/quiz_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:file_picker/file_picker.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:url_launcher/url_launcher.dart';

class FolderDetailPage extends StatefulWidget {
  final String folderId;
  final String folderName;

  const FolderDetailPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  @override
  void initState() {
    super.initState();
    fetch();
  }

  void fetch() async {
    // Fetch files
    await  Provider.of<FilesViewModel>(context, listen: false).fetchFiles(widget.folderId);
    // Fetch quiz sets
      await  Provider.of<QuizSetsViewModel>(context, listen: false).fetchQuizSets(widget.folderId);
  }

  Future<XFile?> _compressImage(File file) async {
    try {
      final dir = file.parent.path;
      final targetPath = '$dir/compressed_${file.uri.pathSegments.last}';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 800,
        minHeight: 800,
      );
      return result ?? XFile(file.path);
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Failed to compress image: $e',
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ).show(context);
      }
      return XFile(file.path);
    }
  }

  Future<XFile?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: kIsWeb ? 800 : null,
        maxHeight: kIsWeb ? 800 : null,
        imageQuality: kIsWeb ? 70 : null,
      );
      if (picked != null && !kIsWeb) {
        return await _compressImage(File(picked.path));
      }
      return picked;
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Failed to pick image: $e',
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ).show(context);
      }
      return null;
    }
  }

  Future<FilePickerResult?> _pickFile() async {
    try {
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt',
          'mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a',
          'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv',
          'jpg', 'jpeg', 'png', 'gif',
          'zip', 'rar', '7z',
          'xls', 'xlsx', 'ppt', 'pptx', 'csv', 'json', 'xml', 'html',
        ],
      );
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Failed to pick file: $e',
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ).show(context);
      }
      return null;
    }
  }

  Future<void> _openFile(FileData file) async {
    if (file.filePath == null || file.filePath!.isEmpty) {
      if (mounted) {
        Flushbar(
          message: 'Invalid file path for: ${file.name}',
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ).show(context);
      }
      return;
    }

    final fileUrl = '${BaseUrl.baseUrl}${file.filePath!.replaceFirst(RegExp(r'^\/+'), '')}';
    final uri = Uri.parse(fileUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          Flushbar(
            message: 'Could not open file: ${file.name}',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ).show(context);
        }
      }
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: 'Error opening file: ${file.name} - $e',
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ).show(context);
      }
    }
  }

  void _showFileDialog({FileData? file, bool isEditing = false}) {
    final nameController = TextEditingController(text: file?.name ?? '');
    XFile? selectedIcon;
    FilePickerResult? selectedFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? 'Edit File' : 'Add File',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'File Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isEditing)
                  ElevatedButton(
                    onPressed: () async {
                      final fileResult = await _pickFile();
                      if (fileResult != null) {
                        setStateDialog(() => selectedFile = fileResult);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Pick File'),
                  ),
                if (selectedFile != null && !isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      selectedFile!.files.single.name,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final icon = await _pickImage();
                    if (icon != null) setStateDialog(() => selectedIcon = icon);
                  },
                  child: Column(
                    children: [
                      selectedIcon != null
                          ? kIsWeb
                          ? FutureBuilder(
                        future: selectedIcon!.readAsBytes(),
                        builder: (_, snapshot) => snapshot.hasData
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const SizedBox(),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(selectedIcon!.path),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.folder, size: 40);
                          },
                        ),
                      )
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        "Select Icon (Optional)",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                  if (nameController.text.isEmpty || (!isEditing && selectedFile == null)) {
                    Flushbar(
                      message: 'Please provide a file name${isEditing ? '' : ' and select a file'}',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                    return;
                  }
                  setStateDialog(() => isProcessing = true);

                  try {
                    if (isEditing && file != null) {
                      await context.read<FilesViewModel>().editFile(
                        ctx,
                        widget.folderId,
                        file.id,
                        nameController.text,
                        iconFile: selectedIcon != null ? File(selectedIcon!.path) : null,
                      );
                    } else {
                      await context.read<FilesViewModel>().addFile(
                        ctx,
                        widget.folderId,
                        nameController.text,
                        filePath: selectedFile!.files.single.path,
                        fileBytes: kIsWeb ? selectedFile!.files.single.bytes : null,
                        fileNameForMime: selectedFile!.files.single.name,
                        iconFile: selectedIcon != null ? File(selectedIcon!.path) : null,
                      );
                    }
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    Flushbar(
                      message: 'Operation failed: $e',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                  } finally {
                    setStateDialog(() => isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuizSetDialog({QuizSetData? quizSet, bool isEditing = false}) {
    final nameController = TextEditingController(text: quizSet?.name ?? '');
    XFile? selectedIcon;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEditing ? 'Edit Quiz Set' : 'Add Quiz Set',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Quiz Set Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final icon = await _pickImage();
                    if (icon != null) setStateDialog(() => selectedIcon = icon);
                  },
                  child: Column(
                    children: [
                      selectedIcon != null
                          ? kIsWeb
                          ? FutureBuilder(
                        future: selectedIcon!.readAsBytes(),
                        builder: (_, snapshot) => snapshot.hasData
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            snapshot.data!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        )
                            : const SizedBox(),
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(selectedIcon!.path),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.folder, size: 40);
                          },
                        ),
                      )
                          : const Icon(Icons.image, size: 50, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text(
                        "Select Icon (Optional)",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                  if (nameController.text.isEmpty) {
                    Flushbar(
                      message: 'Please provide a quiz set name',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                    return;
                  }
                  setStateDialog(() => isProcessing = true);

                  try {
                    if (isEditing && quizSet != null) {
                      await context.read<QuizSetsViewModel>().editQuizSet(
                        ctx,
                        widget.folderId,
                        quizSet.id!,
                        nameController.text,
                        iconFile: selectedIcon != null ? File(selectedIcon!.path) : null,
                      );
                    } else {
                      await context.read<QuizSetsViewModel>().addQuizSet(
                        ctx,
                        widget.folderId,
                        nameController.text,
                        iconFile: selectedIcon != null ? File(selectedIcon!.path) : null,
                      );
                    }
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    Flushbar(
                      message: 'Operation failed: $e',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                  } finally {
                    setStateDialog(() => isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteFileDialog(FileData file) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete File',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text("Are you sure you want to delete '${file.name}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                  setStateDialog(() => isProcessing = true);
                  try {
                    await context.read<FilesViewModel>().deleteFile(ctx, widget.folderId, file.id);
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    Flushbar(
                      message: 'Failed to delete file: $e',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                  } finally {
                    setStateDialog(() => isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteQuizSetDialog(QuizSetData quizSet) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool isProcessing = false;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Delete Quiz Set',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text("Are you sure you want to delete '${quizSet.name}'?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                  setStateDialog(() => isProcessing = true);
                  try {
                    await context.read<QuizSetsViewModel>().deleteQuizSet(ctx, widget.folderId, quizSet.id!);
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    Flushbar(
                      message: 'Failed to delete quiz set: $e',
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ).show(ctx);
                  } finally {
                    setStateDialog(() => isProcessing = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilesList() {
    return Consumer<FilesViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vm.files.isEmpty) {
          return const Center(
            child: Text(
              'No files found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vm.files.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemBuilder: (_, i) {
            final file = vm.files[i];
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: file.iconPath != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      '${BaseUrl.baseUrl}${file.iconPath!}',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.folder, size: 40);
                      },
                    ),
                  )
                      : const Icon(Icons.insert_drive_file, size: 40, color: Colors.grey),
                  title: Text(
                    file.name ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => _openFile(file),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _showFileDialog(file: file, isEditing: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _showDeleteFileDialog(file),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuizSetsList() {
    return Consumer<QuizSetsViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (vm.quizSets.isEmpty) {
          return const Center(
            child: Text(
              'No quiz sets found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vm.quizSets.length,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemBuilder: (_, i) {
            final quizSet = vm.quizSets[i];
            return AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: quizSet.iconPath != null
                      ? ClipOval(
                    child: Image.network(
                      '${BaseUrl.baseUrl}${quizSet.iconPath!}',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(Icons.quiz, size: 40, color: Colors.grey),
                    ),
                  )
                      : const Icon(Icons.quiz, size: 40, color: Colors.grey),
                  title: Text(
                    quizSet.name ?? 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    try {
                      Navigator.pushNamed(
                        context,
                        '/quizSetDetail',
                        arguments: {
                          'quizSetId': quizSet.id,
                          'quizSetName': quizSet.name,
                        },
                      );
                    } catch (e) {
                      Flushbar(
                        message: 'Failed to navigate to quiz set details: $e',
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 3),
                      ).show(context);
                    }
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () => _showQuizSetDialog(quizSet: quizSet, isEditing: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _showDeleteQuizSetDialog(quizSet),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_upload, color: Colors.blueAccent),
                    title: const Text(
                      "Add File",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showFileDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.quiz, color: Colors.blueAccent),
                    title: const Text(
                      "Add Quiz Set",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showQuizSetDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: Container(
        color: Colors.grey[100],
        child: Consumer2<FilesViewModel, QuizSetsViewModel>(
          builder: (_, filesVM, quizSetsVM, __) {
            if (filesVM.isLoading && quizSetsVM.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Files",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildFilesList(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Quiz Sets",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildQuizSetsList(),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
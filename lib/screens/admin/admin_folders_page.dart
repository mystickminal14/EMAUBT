import 'dart:io';
import 'package:ema_app/model/folder_model.dart';
import 'package:ema_app/screens/admin/admin_folder_detail_page.dart';
import 'package:ema_app/view_model/folders/folder_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});
  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final TextEditingController folderController = TextEditingController();
  XFile? selectedImage;
  bool isProcessing = false;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<FolderViewModel>(context, listen: false).fetchFolders();
      }
    });
  }

  /// Compress image for mobile and return XFile
  Future<XFile?> _compressImage(File file) async {
    final dir = file.parent.path;
    final targetPath = '$dir/compressed_${file.uri.pathSegments.last}';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
    );
    if (result != null) {
      _logger.i("Image compressed: ${result.path}");
      return XFile(result.path);
    }
    return XFile(file.path); // fallback if compression fails
  }

  /// Pick image and compress if needed
  Future<XFile?> _pickImage() async {
    _logger.i("Opening image picker...");
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: kIsWeb ? 800 : null,
      maxHeight: kIsWeb ? 800 : null,
      imageQuality: kIsWeb ? 70 : null,
    );

    if (picked != null && !kIsWeb) {
      File file = File(picked.path);
      return await _compressImage(file);
    }

    return picked;
  }

  void _showFolderDialog(BuildContext context,
      {bool isEditing = false, FolderModel? folder}) {
    folderController.clear();
    selectedImage = null;
    isProcessing = false;

    if (isEditing && folder != null) {
      folderController.text = folder.name ?? '';
      _logger.i("Editing folder: ${folder.name}");
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Folder" : "Add New Folder"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: folderController,
                  decoration: const InputDecoration(labelText: 'Folder Name'),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    _logger.i("User tapped to select folder icon...");
                    XFile? newImage = await _pickImage();
                    if (newImage != null && context.mounted) {
                      setDialogState(() => selectedImage = newImage);
                      _logger.i("Image selected: ${newImage.path}");
                    }
                  },
                  child: Column(
                    children: [
                      if (selectedImage != null)
                        kIsWeb
                            ? FutureBuilder(
                                future: selectedImage!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const Icon(Icons.folder, size: 40);
                                },
                              )
                            : Image.file(
                                File(selectedImage!.path),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                      else
                        const Icon(Icons.folder, size: 40),
                      const SizedBox(height: 10),
                      const Text("Select Icon", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            Consumer<FolderViewModel>(
              builder: (context, folderVM, _) => TextButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (folderController.text.isEmpty) {
                          _logger.w("Folder name is empty. Cannot add/edit.");
                          return;
                        }

                        setDialogState(() => isProcessing = true);

                        if (isEditing && folder != null) {
                          _logger.i(
                              "Updating folder ${folder.id}: ${folderController.text}");
                          await folderVM.editFolder(
                            context,
                            folder.id ?? '',
                            folderController.text,
                            selectedImage != null
                                ? File(selectedImage!.path)
                                : null,
                          );
                        } else {
                          _logger
                              .i("Adding new folder: ${folderController.text}");
                          await folderVM.addFolder(
                            context,
                            folderController.text,
                            selectedImage != null
                                ? File(selectedImage!.path)
                                : null,
                          );
                        }

                        if (context.mounted) {
                          setDialogState(() => isProcessing = false);
                          Navigator.pop(context);
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? "Update" : "Add"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, FolderModel folder) {
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this folder?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            Consumer<FolderViewModel>(
              builder: (context, folderVM, _) => TextButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        _logger.i("Deleting folder: ${folder.name}");
                        await folderVM.deleteFolder(context, folder.id ?? '');
                        if (context.mounted) {
                          setDialogState(() => isProcessing = false);
                          Navigator.pop(context);
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Delete", style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderIcon(String? iconUrl) {
    if (iconUrl != null && iconUrl.isNotEmpty) {
      final encodedUrl = Uri.encodeFull(iconUrl);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6), // set 0 for sharp rectangle
        child: Image.network(
          encodedUrl,
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
            _logger.w("Failed to load folder icon: $encodedUrl");
            return const Icon(Icons.folder, size: 40);
          },
        ),
      );
    } else {
      return const Icon(Icons.folder, size: 40);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Folders")),
      body: Consumer<FolderViewModel>(
        builder: (context, folderVM, _) {
          if (folderVM.isLoading && folderVM.folders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (folderVM.folders.isEmpty) {
            return const Center(child: Text("No folders available"));
          }

          return ListView.builder(
            itemCount: folderVM.folders.length,
            itemBuilder: (context, index) {
              final folder = folderVM.folders[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderDetailPage(
                        folderId: folder.id.toString()??'',
                        folderName: folder.name??'',
                      ),
                    ),
                  );
                },
                child: ListTile(
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: _buildFolderIcon(folder.iconUrl),
                  ),
                  title: Text(folder.name ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showFolderDialog(context,
                            isEditing: true, folder: folder),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteFolder(context, folder),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFolderDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
